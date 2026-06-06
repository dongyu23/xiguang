package processor

import "context"

type ImageProcessor interface {
	GenerateThumbnail(ctx context.Context, objectKey string) (thumbnailKey string, err error)
}
