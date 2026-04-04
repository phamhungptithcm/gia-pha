# Production Release Runbook

_Cập nhật: 04/04/2026_

Tài liệu này là runbook ngắn để team kiểm tra mọi cấu hình production trước khi promote BeFam từ `main`.

## 1. Kiểm tra GitHub production environment

Chuẩn bị:

- Đăng nhập `gh auth login`
- Có quyền đọc `phamhungptithcm/gia-pha`

Chạy audit:

```bash
./scripts/audit_github_environment.sh --repo phamhungptithcm/gia-pha --env production --strict
```

Script sẽ kiểm tra:

- GitHub `production` vars còn thiếu
- GitHub `production` secrets còn thiếu
- `mobile/befam/web/app-ads.txt` đã thay placeholder hay chưa
- `prevent_self_review` của environment `production`

Nếu script fail, không promote production.

## 2. Điền GitHub vars/secrets production

Nguồn template:

- [scripts/github-production.env.example](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/scripts/github-production.env.example)
- [scripts/setup_github_production_config.sh](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/scripts/setup_github_production_config.sh)

Thiết lập:

```bash
source scripts/github-production.env.example
# điền giá trị thật
./scripts/setup_github_production_config.sh --repo phamhungptithcm/gia-pha --env production
```

Các nhóm phải có đủ:

- Firebase production vars
- App runtime vars
- Real AdMob app IDs và unit IDs
- Android signing secrets
- iOS signing secrets
- OIDC deploy secrets

## 3. Hoàn tất app-ads.txt

File cần điền:

- [app-ads.txt](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/mobile/befam/web/app-ads.txt)

Format:

```txt
google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0
```

Yêu cầu:

- Thay `pub-xxxxxxxxxxxxxxxx` bằng publisher ID thật của AdMob
- Commit file vào repo trước khi cắt RC production
- Không dùng placeholder hoặc comment TODO ở production

## 4. Cắt release candidate từ main

Điều kiện:

- Branch CI xanh
- Không còn `Blocker` trong [production-readiness-checklist.md](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/production-readiness-checklist.md)
- Audit GitHub production env pass

Sau đó:

1. Merge code vào `main`
2. Chờ `CD - Release Main` chạy xong
3. Lấy `release_tag` đã publish
4. Cài artifact Android/iOS lên máy thật hoặc store test channel
5. Chạy smoke test release

## 5. Smoke test tối thiểu

- OTP phone login
- child login
- push notification background
- create genealogy
- create branch
- funds
- scholarship
- billing
- legal pages `/privacy`, `/terms`, `/account-deletion`

Nếu có lỗi blocker, không promote Firebase/web production và không submit store build.

## 6. Promote production

Sau khi release candidate đã sign-off:

1. Run `CD - Deploy Firebase (Production)` với `release_tag`
2. Verify Functions, Scheduler, Firestore, App Check, logs
3. Run `CD - Deploy Web Hosting (Production)` với cùng `release_tag`
4. Verify web production routes, legal pages, `app-ads.txt`
5. Submit Android/iOS binaries vào track test của store
6. Promote public release sau khi test pass

## 7. Chủ sở hữu chính

- Platform: GitHub env, workflow, deploy, budgets, alerts
- Mobile: signing, iOS capabilities, RC QA
- Backend/Firebase: Firebase project, App Check, push, scheduler, rules
- Growth: AdMob IDs, app-ads.txt
- Product/Legal: privacy, terms, account deletion policy, store metadata
