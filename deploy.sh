project_id=$( gcloud info --format='value(config.project)' )

current_redact=$(gsutil list | grep 'redact-[\d]*' -m 1 -o -P | head -1)

read -p 'Redacted Bucket ['"$current_redact"']: ' redact_bucket
redact_bucket=${redact_bucket:-${current_redact}}

read -p 'Region [us-central1]: ' region
region=${region:-us-central1}

read -p 'GCR Image Tag [redact-image]: ' image_tag
image_tag=${image_tag:-redact-image}

read -p 'Cloud Run Service [redact-run]: ' service
service=${service:-redact-run}

# Set region
gcloud config set run/region ${region}

# Build and Deploy Cloud Run service
gcloud builds submit --config=cloudbuild.yaml --substitutions=_IMAGE_TAG="${image_tag}",_REDACTED_BUCKET_NAME="${redact_bucket}"
gcloud run deploy ${service} --image us.gcr.io/${project_id}/${image_tag} --format='value(status.url)' --platform=managed --no-allow-unauthenticated