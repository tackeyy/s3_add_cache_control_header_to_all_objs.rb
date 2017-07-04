# frozen_string_literal: true

require 'aws-sdk'
require 'securerandom'

REGION_NAME = 'us-east-1'           # your region name
BUCKET_NAME = 'bucket_name'         # your bucket name
BUCKET_PREFIX = 'bucket_prefix'     # your bucket name

ACCESS_KEY = 'access_key'
SECRET_KEY = 'secret_key'
CREDENTIALS = Aws::Credentials.new(ACCESS_KEY, SECRET_KEY)

CACHE_CONTROL = 'max-age=604800'    # 86400 = 7days
CONTENT_TYPE = 'image/jpeg'

s3 = Aws::S3::Client.new(region: REGION_NAME, credentials: CREDENTIALS)

paths = s3.list_objects(bucket: BUCKET_NAME, prefix: BUCKET_PREFIX)
          .contents.map(&:key)
          .select { |path| path.end_with? '.jpg' }

paths.each do |path|
  s3.copy_object(
    bucket: BUCKET_NAME,
    copy_source: "#{BUCKET_NAME}/#{path}",
    key: "#{path}.tmp"
  )

  s3.delete_object(
    bucket: BUCKET_NAME,
    key: path
  )

  s3.copy_object(
    acl: 'public-read',
    bucket: BUCKET_NAME,
    copy_source: "#{BUCKET_NAME}/#{path}.tmp",
    key: path,
    cache_control: CACHE_CONTROL,
    content_type: CONTENT_TYPE,
    metadata_directive: 'REPLACE'
  )

  s3.delete_object(
    bucket: BUCKET_NAME,
    key: "#{path}.tmp"
  )
end

# In case Cloudfront is used

DISTRIBUTION_ID = 'my_distribution_id' # your id

cloudfront = Aws::CloudFront::Client.new(
  region: REGION_NAME,
  credentials: CREDENTIALS
)

cloudfront.create_invalidation(
  distribution_id: DISTRIBUTION_ID,
  invalidation_batch: {
    paths: {
      quantity: paths.size,
      items: paths.map { |path| '/' + path }
    },
    caller_reference: SecureRandom.uuid
  }
)
