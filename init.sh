#! /bin/bash

# Input & Variables

read -p 'Region [us-central1]: ' region
region=${region:-us-central1}

random_suffix=$( shuf -i 10000-100000 -n 1 )
read -p 'Source Bucket [source-'"${random_suffix}"']: ' source_bucket
source_bucket=${source_bucket:-source-${random_suffix}}

random_suffix=$( shuf -i 10000-100000 -n 1 )
read -p 'Redacted Bucket [redact-'"${random_suffix}"']: ' redact_bucket
redact_bucket=${redact_bucket:-redact-${random_suffix}}

read -p 'Pub/Sub Topic Name [redact-pubsub-topic]: ' ps_topic
ps_topic=${ps_topic:-redact-pubsub-topic}

read -p 'Pub/Sub Topic Name [redact-pubsub-subscription]: ' ps_subscription
ps_subscription=${ps_subscription:-redact-pubsub-subscription}

read -p 'Pub/Sub Subscription Service Account [redact-run-pubsub-invoker]: ' ps_sa
ps_sa=${ps_sa:-redact-run-pubsub-invoker}

read -p 'GCR Image Tag [redact-image]: ' image_tag
image_tag=${image_tag:-redact-image}

read -p 'Cloud Run Service [redact-run]: ' service
service=${service:-redact-run}

project_id=$( gcloud info --format='value(config.project)' )
project_number=$( gcloud projects list --filter=${project_id} --format='value(projectNumber)' )

# Set region
gcloud config set run/region ${region}

# Activate APIs
gcloud services enable cloudbuild.googleapis.com run.googleapis.com pubsub.googleapis.com dlp.googleapis.com

# Make buckets
gsutil mb gs://${source_bucket}
gsutil mb gs://${redact_bucket}

# Build and Deploy Cloud Run service
gcloud builds submit --config=cloudbuild.yaml --substitutions=_IMAGE_TAG="${image_tag}",_REDACTED_BUCKET_NAME="${redact_bucket}"
service_url=$(gcloud run deploy ${service} --image us.gcr.io/${project_id}/${image_tag} --format='value(status.url)' --platform=managed --no-allow-unauthenticated)

# Set up Pub/Sub topic, subscription, notification, and invocation service account
gcloud pubsub topics create ${ps_topic}
gcloud iam service-accounts create ${ps_sa}
gcloud run services add-iam-policy-binding ${service} --member=serviceAccount:${ps_sa}@${project_id}.iam.gserviceaccount.com --role=roles/run.invoker --platform=managed
gcloud projects add-iam-policy-binding ${project_id} --member=serviceAccount:service-${project_number}@gcp-sa-pubsub.iam.gserviceaccount.com --role=roles/iam.serviceAccountTokenCreator
gcloud pubsub subscriptions create ${ps_subscription} --topic ${ps_topic} --push-endpoint=${service_url}/ --push-auth-service-account=${ps_sa}@${project_id}.iam.gserviceaccount.com
gsutil notification create -t projects/${project_id}/topics/${ps_topic} -f json gs://${source_bucket}