# Google OAuth 설정 가이드 – Teamply

## 필요한 값들
- Supabase Callback URL: https://waxjtcxdgulbdofycywr.supabase.co/auth/v1/callback
- App URL: https://5060-ia4lglfzrroo79183hrn4-dfc00ec5.sandbox.novita.ai

## STEP 1: Google Cloud Console 설정
URL: https://console.cloud.google.com/

1. 프로젝트 선택 또는 새 프로젝트 생성
2. "APIs & Services" → "OAuth consent screen"
   - User Type: External
   - App name: Teamply
   - User support email: 본인 이메일
   - Developer contact: 본인 이메일
   - Save and Continue
3. "APIs & Services" → "Credentials" → "+ CREATE CREDENTIALS" → "OAuth client ID"
   - Application type: Web application
   - Name: Teamply Web
   - Authorized redirect URIs 추가:
     https://waxjtcxdgulbdofycywr.supabase.co/auth/v1/callback
   - CREATE → Client ID와 Client Secret 복사

## STEP 2: Supabase에 설정
URL: https://supabase.com/dashboard/project/waxjtcxdgulbdofycywr/auth/providers

1. Google 찾기 → Enable 토글 ON
2. Client ID: (Google에서 복사한 값)
3. Client Secret: (Google에서 복사한 값)
4. Save

## STEP 3: 완료
- Client ID와 Secret을 여기에 붙여넣으면 코드에 자동 반영됩니다.
