# Supabase setup

1. **Create a project** at supabase.com (pick the Singapore region, closest to
   Metro Manila). Save the database password somewhere safe.
2. **Create the tables and security rules:** SQL Editor -> New query -> paste
   `schema.sql` -> Run.
3. **Turn off public sign-ups:** Authentication -> Sign In / Providers -> Email
   -> switch off "Allow new users to sign up". The app has no sign-up screen,
   so only accounts you create by hand can exist. Leave anonymous sign-ins off.
4. **Create authorized users:** Authentication -> Users -> Add user -> Create
   new user. Use a `@tip.edu.ph` email and a password, and tick "Auto Confirm User".
5. **Copy your keys:** Project Settings -> API Keys.
   - Project URL: goes in the app and in the simulator.
   - Publishable (anon) key: goes in the app later. Safe to ship.
   - Secret (service_role) key: goes ONLY in `simulator/.env`. Never commit it,
     never put it in the app, never paste it in chat.

## Check the security rules

Replace the two placeholders and run in PowerShell. Drivers (anon key) must see
summaries but no live lane data:

```powershell
$h = @{ apikey = "<publishable or anon key>" }
$u = "https://<project-ref>.supabase.co/rest/v1"
Invoke-RestMethod "$u/intersections?select=*" -Headers $h        # 5 rows
Invoke-RestMethod "$u/intersection_live?select=*" -Headers $h    # empty: []
```

Writing with the anon key must fail:

```powershell
Invoke-RestMethod "$u/events" -Method Post -Headers ($h + @{ "Content-Type" = "application/json" }) -Body '{"occurred_at":"2026-10-19T00:00:00Z","intersection_id":1,"lane":"All","type":"idleMode","description":"x"}'
# expected: an error (401/403)
```