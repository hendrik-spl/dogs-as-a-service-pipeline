from src.dog_api_pipeline import main

def dog_pipeline_handler(request):
    """
    Cloud Function HTTP handler
    """
    print("Starting dog pipeline handler...")
    return main(request)