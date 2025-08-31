import dlt
import requests
from datetime import datetime
import json
from typing import List, Dict, Any


@dlt.resource(
    name="dog_breeds",
    write_disposition="replace",  # Replace data each run since it's a static dataset
    columns={"extracted_at": {"data_type": "timestamp"}}
)
def fetch_dog_breeds() -> List[Dict[str, Any]]:
    """
    Fetch dog breed data from TheDogAPI.com
    """
    api_url = "https://api.thedogapi.com/v1/breeds"
    
    try:
        response = requests.get(api_url)
        response.raise_for_status()
        
        breeds_data = response.json()
        
        # Add extraction metadata
        extraction_time = datetime.utcnow().isoformat()
        
        for breed in breeds_data:
            breed["extracted_at"] = extraction_time
            breed["extraction_date"] = datetime.utcnow().date().isoformat()
        
        print(f"Successfully fetched {len(breeds_data)} dog breeds")
        return breeds_data
        
    except requests.exceptions.RequestException as e:
        print(f"Error fetching data from Dog API: {e}")
        raise


def save_to_cloud_storage(data: List[Dict[str, Any]], date_partition: str) -> None:
    """
    Save raw JSON data to Cloud Storage partitioned by date
    Using dlt's filesystem destination with GCS staging
    """
    import os
    os.environ.setdefault('BUCKET_URL', 'gs://dog-breed-raw-data')
    os.environ.setdefault('DESTINATION__BIGQUERY__LOCATION', 'europe-north2')

    # Create filesystem pipeline for Cloud Storage
    filesystem_pipeline = dlt.pipeline(
        pipeline_name="dog_breeds_raw_storage",
        destination="filesystem",
        dataset_name=f"raw_data_{date_partition[:4]}_{date_partition[5:7]}_{date_partition[8:10]}"
    )

    @dlt.resource(name="raw_dog_api_data")
    def raw_data():
        return data
    
    # Run the filesystem pipeline to save to GCS
    filesystem_pipeline.run(raw_data())
    print(f"Raw data saved to Cloud Storage for date: {date_partition}")


def load_to_bigquery() -> None:
    """
    Main pipeline function to load dog breeds data to BigQuery
    """
    # Create the main BigQuery pipeline
    pipeline = dlt.pipeline(
        pipeline_name="dog_breeds_pipeline",
        destination="bigquery",
        dataset_name="bronze"
    )
    
    # Fetch data
    breeds_data = list(fetch_dog_breeds())
    
    # Save raw data to Cloud Storage (partitioned)
    current_date = datetime.utcnow().date().isoformat()
    # print(f"Skipping raw data save to Cloud Storage for now")
    save_to_cloud_storage(breeds_data, current_date)
    
    # Load to BigQuery bronze table
    load_info = pipeline.run(fetch_dog_breeds())
    
    print(f"Pipeline completed successfully!")
    print(f"Tables loaded: {load_info}")
    
    return load_info
    

# Cloud Function entry point
def main(request=None):
    """
    Entry point for Cloud Function
    This function will be triggered by Cloud Scheduler
    """
    try:
        load_info = load_to_bigquery()
        return {
            "status": "success",
            "message": "Dog breeds data loaded successfully",
            "load_info": str(load_info)
        }
    except Exception as e:
        print(f"Pipeline failed: {str(e)}")
        return {
            "status": "error",
            "message": f"Pipeline failed: {str(e)}"
        }


if __name__ == "__main__":
    main()