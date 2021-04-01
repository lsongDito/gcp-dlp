# GCP Redaction AI

An implementation of an automated redaction pipeline on Google Cloud using Google Data Loss Prevention (DLP). 
**Specifically built for redacting .TIF(F) files.**

## Automation Architecture
Google Storage Event -> Pub/Sub Topic (Notification) -> Pub/Sub Subscription (Notification) -> Cloud Run (DLP)

## Steps for deployment

  1. Login to GCP Console
  
  2. Create a new or select an existing project
  
  3. Launch a Cloud Shell instance (terminal icon in the top right)
  
  4. Clone this repository and set as current directory
 
   ```sh
     git clone https://github.com/neilsong/gcp-redaction-ai.git && cd gcp-redaction-ai/
   ```
   
  5. Run `init.sh` on inital set-up and follow the prompts
  
  ```sh
     ./init.sh
   ```
   
  6. (Dev-only) If modifying any part of the app, run `deploy.sh` to build and deploy changes
  
  ```sh
     ./deploy.sh
   ```
