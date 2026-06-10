import sys
import json
import google.auth.transport.requests
import google.oauth2.service_account
import requests

SERVICE_ACCOUNT_FILE = 'service-account.json'
PROJECT_ID = 'logired-d4dda'

def get_access_token():
    creds = google.oauth2.service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/firebase.messaging']
    )
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token

def send_remote_delete(fcm_token, target_user_id):
    access_token = get_access_token()
    url = f'https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send'
    payload = {
        'message': {
            'token': fcm_token,
            'data': {
                'action': 'remote_delete_sensitive_data',
                'scope': 'user',
                'targetUserId': target_user_id,
                'reason': 'remote_wipe_test'
            }
        }
    }
    response = requests.post(
        url,
        headers={
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        },
        json=payload
    )
    if response.ok:
        print(f'Mensaje enviado correctamente: {response.json()}')
    else:
        print(f'Error {response.status_code}: {response.text}')

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Uso: python send_fcm.py <FCM_TOKEN> <TARGET_USER_ID>')
        print('Ejemplo: python send_fcm.py eKx3abc...xyz admin')
        sys.exit(1)
    send_remote_delete(sys.argv[1], sys.argv[2])
