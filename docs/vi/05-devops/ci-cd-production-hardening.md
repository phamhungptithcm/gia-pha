# Tăng Cường CI/CD Cho Production

Tài liệu này mô tả mô hình CI/CD an toàn cho production của BeFam.

## Mô Hình Nhánh Release

- `staging`: nhánh tích hợp trước production.
- `main`: nhánh phát hành production.
- Luồng phát hành: `staging -> main` qua pull request.

## Chính Sách Bảo Vệ Bắt Buộc

Áp dụng cho cả `staging` và `main`:

- Bắt buộc merge qua pull request.
- Tối thiểu 1 approval.
- Bắt buộc review từ CODEOWNERS.
- Bắt buộc approval cho lần push cuối.
- Bắt buộc resolve toàn bộ thread review.
- Bắt buộc pass các check:
  - `ci-docs`
  - `ci-functions`
  - `ci-mobile`
  - `security-dependency-review`
  - `security-trivy-fs`
  - `security-gitleaks`
  - `security-trivy-images`
- Bắt buộc commit có chữ ký.
- Không cho bypass rule.

## Bảo Vệ Environment

- `production`:
  - Chỉ deploy từ `main`.
  - Bật required reviewer.
  - Bật chống tự duyệt (`prevent self-review`).
  - Tắt admin bypass.
- `staging`:
  - Chỉ deploy từ `staging`.
  - Tắt admin bypass.

## Thứ Tự Workflow

### 1) Gate ở PR/Branch

- `CI - Branch Quality Gates`: docs, functions, mobile,
  dependency review, Trivy (filesystem + image), gitleaks.

### 2) Release Production

Workflow `CD - Release Main` chạy theo thứ tự:

1. Chạy quality gates.
2. Chạy preflight production để kiểm tra secret bắt buộc và cấu hình Firestore billing.
3. Tạo version/tag.
4. Build artifact Android, iOS, Web.
5. Sinh manifest và checksum.
6. Sinh provenance attestation.
7. Publish GitHub Release.

### 3) Deploy Production

1. `CD - Deploy Firebase (Production)` chạy sau khi `CD - Release Main` thành công.
2. `CD - Deploy Web Hosting (Production)` chạy sau khi
   `CD - Deploy Firebase (Production)` thành công.

Luồng này giúp deploy đúng thứ tự, không rời rạc.

## Rollback

Dùng workflow `CD - Rollback Production` với:

- `release_tag`: tag cần rollback về.
- `deploy_target`: `all`, `firebase`, hoặc `web`.

Rollback dùng artifact bất biến theo tag release.

## Danh Tính Và Secrets

### Production (bắt buộc)

Deploy/rollback production chỉ dùng OIDC:

- `GCP_WORKLOAD_IDENTITY_PROVIDER` (secret)
- `GCP_SERVICE_ACCOUNT_EMAIL` (secret)

Đã gỡ fallback key `FIREBASE_SERVICE_ACCOUNT` khỏi workflow production.

### Staging

`CD - Deploy Staging` vẫn hỗ trợ fallback JSON key trong giai đoạn chuyển đổi.

## Truy Vết Và Tái Lập

Mỗi release có:

- artifact Android/iOS/Web có version,
- `release-manifest-<version>.json`,
- `checksums-<version>.txt`,
- provenance attestations.

Nhờ đó việc kiểm toán và tái lập deploy theo từng release rõ ràng hơn.
