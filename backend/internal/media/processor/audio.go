package processor

type AudioProcessor interface {
	ProbeDuration(objectKey string) (durationMS int64, err error)
}
