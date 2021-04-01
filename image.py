import os
import tempfile
from PIL import Image

from google.cloud import storage, dlp_v2

dlp_client = dlp_v2.DlpServiceClient()
storage_client = storage.Client()
image_redaction_configs = [
    {"info_type": 
        { "name": "STREET_ADDRESS"}}, 
    {"info_type":
        { "name": "PHONE_NUMBER"
    }},
    {"info_type": 
        { "name": "PERSON_NAME"
    }},
    {"info_type": 
        { "name": "DATE_OF_BIRTH"
    }},
    {"info_type": 
        { "name": "GENDER"
    }}
]

inspect_config = {
    "info_types": [
        { "name": "DATE_OF_BIRTH"},
        { "name": "PERSON_NAME"},
        { "name": "PHONE_NUMBER"},
        { "name": "STREET_ADDRESS"},
        { "name": "GENDER"}
    ],
}

def redact_image(data):
    file_name = data["name"]
    bucket_name = data["bucket"]
    current_blob = storage_client.bucket(bucket_name).get_blob(file_name)

    _, temp_local_filename = tempfile.mkstemp()

    # Download file from bucket.
    current_blob.download_to_filename(temp_local_filename)
    print(f"Image {file_name} was downloaded to {temp_local_filename}.")

    # Convert TIF to BMP.
    _, temp_bmp_local_filename = tempfile.mkstemp()
    with Image.open(temp_local_filename) as tif:
        tif.save(temp_bmp_local_filename, "BMP")

    # Construct the byte_item, containing the file's byte data.
    with open(temp_bmp_local_filename, mode="rb") as f:
        byte_item = {"type_": dlp_v2.FileType.IMAGE, "data": f.read()}

    # Convert the project id into a full resource id.
    parent = f"projects/{ os.getenv('PROJECT') }"

    # Call the API.
    response = dlp_client.redact_image(
        request={
            "parent": parent,
            "inspect_config": inspect_config,
            "image_redaction_configs": image_redaction_configs,
            "byte_item": byte_item,
        }
    )

    _, new_temp_local_filename = tempfile.mkstemp()
    # Write out the results.
    with open(new_temp_local_filename, mode="wb") as f:
        f.write(response.redacted_image)

    # Convert BMP to TIFF.
    _, new_temp_tif_local_filename = tempfile.mkstemp()
    with Image.open(new_temp_local_filename) as bmp:
        bmp.save(new_temp_tif_local_filename, "TIFF", compression="None")

    print(
        "Wrote {byte_count} to {filename}".format(
            byte_count=len(response.redacted_image), filename=new_temp_tif_local_filename
        )
    )

    # Upload result to a second bucket, to avoid re-triggering the function.
    redacted_bucket_name = os.getenv('REDACTED_BUCKET_NAME')
    redacted_bucket = storage_client.bucket(redacted_bucket_name)
    new_blob = redacted_bucket.blob(file_name)
    new_blob.upload_from_filename(new_temp_tif_local_filename)
    print(f"Redacted image uploaded to: gs://{redacted_bucket_name}/{file_name}")

    # Delete the temporary file.
    os.remove(temp_local_filename)
    os.remove(new_temp_local_filename)
    os.remove(temp_bmp_local_filename)
    os.remove(new_temp_tif_local_filename)
