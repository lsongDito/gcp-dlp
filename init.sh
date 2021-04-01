#! /bin/bash

# Input & Variables
project_id = $( gcloud info --format='value(config.project)' )
project_number = $( gcloud projects list --filter=word-counter-bot-ai --format='value(projectNumber)' )

read -p 'Region [us-central1]: ' region
region=${region:-us-central1}

random_suffix=$( shuf -i 10000-100000 -n 1 )
read -p 'Source Bucket [forms-'"${random_suffix}"']: ' source_bucket
source_bucket=${source_bucket:-forms-${random_suffix}}

random_suffix=$( shuf -i 10000-100000 -n 1 )
read -p 'Redacted Bucket [redact-'"${random_suffix}"']: ' redact_bucket
redact_bucket=${redact_bucket:-redact-${random_suffix}}

read -p 'Pub/Sub Topic Name [redact-pubsub-topic]: ' ps_topic
ps_topic=${ps_topic:-redact-pubsub-topic}

read -p 'Pub/Sub Topic Name [redact-pubsub-subscription]' ps_subscription
ps_subscription=${ps_subscription:-redact-pubsub-subscription}

read -p 'Pub/Sub Subscription Service Account [redact-run-pubsub-invoker]: ' ps_sa
ps_sa=${ps_sa:-redact-run-pubsub-invoker}

read -p 'GCR Image Tag [redact-image]: ' image_tag
image_tag=${image_tag:-redact-image}

read -p 'Cloud Run Service [redact-run]: ' service
service=${service:-redact-run}

# Set region
gcloud config set run/region ${region}

# Activate APIs
gcloud services enable cloudbuild.googleapis.com run.googleapis.com pubsub.googleapis.com

# Make buckets
gsutil mb gs://${source_bucket}
gsutil mb gs://${redact_bucket}

# Build and Deploy Cloud Run service
gcloud builds submit --tag gcr.io/${project_id}/${image_tag} --config=cloudbuild.yaml --substitutions=_SERVICE_NAME="${service}",_REDACTED_BUCKET_NAME="${redact_bucket}"
service_url=$(gcloud run deploy ${service} --image gcr.io/${project_id}/${image_tag} --format='value(status.url)' --platform managed)

# Set up Pub/Sub topic, subscription, notification, and invocation service account
gcloud pubsub topics create ${ps_topic}
gcloud iam service-accounts create ${ps_sa}
gcloud run services add-iam-policy-binding ${service} --member=serviceAccount:${ps_sa}@${project_id}.iam.gserviceaccount.com --role=roles/run.invoker
gcloud pubsub subscriptions create ${ps_subscription} --topic ${ps_topic} --push-endpoint=${service_url}/ --push-auth-service-account=${ps_sa}@${project_id}.iam.gserviceaccount.com
gsutil notification create -t ${ps_topic} -f json gs://${source_bucket}