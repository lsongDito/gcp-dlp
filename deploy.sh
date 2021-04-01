read -p 'GCR Image Tag [redact-image]: ' image_tag
image_tag=${image_tag:-redact-image}

read -p 'Cloud Run Service [redact-run]: ' service
service=${service:-redact-run}

# Build and Deploy Cloud Run service
gcloud builds submit --tag gcr.io/${project_id}/${image_tag} --config=cloudbuild.yaml --substitutions=_SERVICE_NAME="${service}",_REDACTED_BUCKET_NAME="${redact_bucket}"
service_url=$(gcloud run deploy ${service} --image gcr.io/${project_id}/${image_tag} --format='value(status.url)' --platform managed)