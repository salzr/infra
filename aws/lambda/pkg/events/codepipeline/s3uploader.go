package codepipeline

import (
	"fmt"
	"io/ioutil"
	"log"
	"mime"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/codepipeline"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"

	"github.com/salzr/infra/aws/lambda/pkg/util"
)

const (
	codePipelineEvent = "CodePipeline Job"
	logInfoPattern    = "%s [CodePipelineEvent=%s] %s\n"

	bucket = "www.iomediums.com"
)

type service struct {
	jobID      string
	downloader *s3manager.Downloader
	uploader   *s3manager.Uploader
	cp         *codepipeline.CodePipeline
	logger     evtlogger
}

type evtlogger struct {
	pattern string
}

type DirectoryIterator struct {
	filePaths []string
	bucket    string
	err       error
	next      struct {
		path string
		f    *os.File
	}
}

func NewFilesIterator(bucket string, paths []string) s3manager.BatchUploadIterator {
	return &DirectoryIterator{
		bucket:    bucket,
		filePaths: paths,
	}
}

func NewService(evt events.CodePipelineEvent) (*service, error) {
	cred := evt.CodePipelineJob.Data.ArtifactCredentials
	sess := session.Must(session.NewSession(&aws.Config{
		Credentials: credentials.NewStaticCredentialsFromCreds(credentials.Value{
			AccessKeyID:     cred.AccessKeyID,
			SecretAccessKey: cred.SecretAccessKey,
			SessionToken:    cred.SessionToken,
		}),
	}))

	return &service{
		jobID:      evt.CodePipelineJob.ID,
		downloader: s3manager.NewDownloader(sess),
		uploader:   s3manager.NewUploader(session.Must(session.NewSession())),
		cp:         codepipeline.New(session.Must(session.NewSession())),
		logger: evtlogger{
			pattern: fmt.Sprintf(logInfoPattern, "%s", evt.CodePipelineJob.ID, "%v"),
		},
	}, nil
}

func (l evtlogger) Info(m string) {
	log.Printf(l.pattern, "I", m)
}

func (l evtlogger) Error(e error) error {
	log.Printf(l.pattern, "E", e)
	return e
}

func (iter *DirectoryIterator) Next() bool {
	if len(iter.filePaths) == 0 {
		iter.next.f = nil
		return false
	}

	f, err := os.Open(iter.filePaths[0])
	iter.err = err

	iter.next.f = f
	iter.next.path = strings.Join(strings.Split(iter.filePaths[0], "/")[4:], "/")

	iter.filePaths = iter.filePaths[1:]
	return iter.Err() == nil
}

func (iter *DirectoryIterator) Err() error {
	return iter.err
}

func (iter *DirectoryIterator) UploadObject() s3manager.BatchUploadObject {
	f := iter.next.f
	ext := filepath.Ext(iter.next.path)
	ctype := mime.TypeByExtension(ext)

	return s3manager.BatchUploadObject{
		Object: &s3manager.UploadInput{
			Bucket:      &iter.bucket,
			Key:         &iter.next.path,
			Body:        f,
			ContentType: aws.String(ctype),
			ACL:         aws.String("public-read"),
		},
		After: func() error {
			return f.Close()
		},
	}
}

func (s service) Success() error {
	_, err := s.cp.PutJobSuccessResult(&codepipeline.PutJobSuccessResultInput{
		JobId: aws.String(s.jobID),
	})
	return err
}

func (s service) Failed() error {
	_, err := s.cp.PutJobFailureResult(&codepipeline.PutJobFailureResultInput{
		JobId: aws.String(s.jobID),
	})
	return err
}

func errOut(err error) error {
	if aerr, ok := err.(awserr.Error); ok {
		return aerr
	}
	return err
}

func S3UploaderEventHandler(evt events.CodePipelineEvent) error {
	svc, err := NewService(evt)
	if err != nil {
		return err
	}

	logger := svc.logger
	logger.Info(fmt.Sprintf("event=(%s) received", codePipelineEvent))

	artifact := evt.CodePipelineJob.Data.InputArtifacts[0].Location.S3Location

	td, err := ioutil.TempDir("", "artifact")
	if err != nil {
		return logger.Error(errOut(err))
	}
	fn := filepath.Base(artifact.ObjectKey)
	fp := filepath.Join(td, fn)
	f, err := os.Create(fp)
	if err != nil {
		svc.Failed()
		return logger.Error(errOut(err))
	}

	b, err := svc.downloader.Download(f, &s3.GetObjectInput{
		Bucket: aws.String(artifact.BucketName),
		Key:    aws.String(artifact.ObjectKey),
	})
	if err != nil {
		svc.Failed()
		return logger.Error(errOut(err))
	}
	logger.Info(fmt.Sprintf("file downloaded, %d bytes", b))

	files, err := util.Unzip(fp, td)
	if err != nil {
		svc.Failed()
		return logger.Error(errOut(err))
	}

	iter := NewFilesIterator(bucket, files)
	if err := svc.uploader.UploadWithIterator(aws.BackgroundContext(), iter); err != nil {
		svc.Failed()
		return logger.Error(errOut(err))
	}

	return svc.Success()
}
