import time
import os
import requests
import boto3
import concurrent.futures

# --- CONFIGURATION (READ FROM ENVIRONMENT) ---
# Set these in your terminal before running: 
# export TEST_PASSWORD="your-password"
EMAIL = "k-hoff-mann@web.de"
PASSWORD = os.getenv("TEST_PASSWORD") 

if not PASSWORD:
    print("Error: Please set the TEST_PASSWORD environment variable.")
    exit(1)

CLIENT_ID = "36mt4qdm70ccep15cu1ufgdhoc"
API_URL_US = "https://jn45v0fp3i.execute-api.us-east-1.amazonaws.com"
API_URL_EU = "https://me19b2bkg1.execute-api.eu-west-1.amazonaws.com"

# --- 1. AUTHENTICATE WITH COGNITO ---
def get_jwt_token():
    print("Authenticating with Cognito in us-east-1...")
    client = boto3.client('cognito-idp', region_name='us-east-1')
    
    response = client.initiate_auth(
        AuthFlow='USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': EMAIL,
            'PASSWORD': PASSWORD
        },
        ClientId=CLIENT_ID
    )
    return response['AuthenticationResult']['IdToken']

# --- 2. API CALL WORKER ---
def call_endpoint(url, endpoint, region_name, token):
    headers = {'Authorization': f"Bearer {token}"}
    full_url = f"{url}{endpoint}"
    
    start_time = time.time()
    response = requests.get(full_url, headers=headers)
    end_time = time.time()
    
    latency = (end_time - start_time) * 1000 # convert to milliseconds
    
    try:
        data = response.json()
        return {
            "endpoint": endpoint,
            "target_region": region_name,
            "status": response.status_code,
            "latency_ms": round(latency, 2),
            "response": data
        }
    except Exception as e:
        return {"endpoint": endpoint, "target_region": region_name, "error": f"Raw Response: {response.text}", "status": response.status_code}

# --- 3. CONCURRENT EXECUTION ---
def main():
    try:
        token = get_jwt_token()
        print("Successfully retrieved JWT Token.\n")
    except Exception as e:
        print(f"Authentication failed: {e}")
        return

    # Define tasks to run concurrently
    tasks = [
        (API_URL_US, '/greet', 'us-east-1'),
        (API_URL_EU, '/greet', 'eu-west-1'),
        (API_URL_US, '/dispatch', 'us-east-1'),
        (API_URL_EU, '/dispatch', 'eu-west-1')
    ]

    print("Executing concurrent requests to /greet and /dispatch...\n")
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        futures = [
            executor.submit(call_endpoint, url, endpoint, region, token) 
            for url, endpoint, region in tasks
        ]
        
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            print(f"[{result['target_region']}] {result['endpoint']}")
            print(f"  Status:  {result.get('status')}")
            print(f"  Latency: {result.get('latency_ms')} ms")
            print(f"  Body:    {result.get('response', result.get('error'))}\n")

if __name__ == "__main__":
    main()