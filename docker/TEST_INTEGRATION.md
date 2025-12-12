# Test Integration in Automated Deployment

## Overview

Tests are now fully integrated into the automated deployment process. Tests run **before** deployment, ensuring that only tested code is deployed to production.

## Test Execution Flow

```
1. Pre-flight Checks
2. Build Docker Image
3. Run Tests ← NEW: Tests run here (before deployment)
4. Deploy Services (only if tests pass)
5. Health Checks
```

## Test Service Configuration

A dedicated `test` service has been added to `docker-compose.sira-community.app.yml`:

- **Environment**: `RAILS_ENV=test`
- **Database**: Uses test database (`sira_community_test`)
- **Dependencies**: Requires `migrate` service to complete first
- **Profile**: Uses `test` profile (only starts when explicitly requested)
- **Command**: Runs `rake db:test:prepare` then `rspec --format documentation`

## Running Tests

### As Part of Automated Deployment

Tests run automatically during deployment:

```bash
# Run full deployment with tests (default)
./build-and-deploy.sh

# Skip tests (not recommended for production)
./build-and-deploy.sh --skip-tests
```

### Manually Run Tests

```bash
# Start migrations first
docker-compose -f docker-compose.sira-community.app.yml up -d migrate

# Wait for migrations to complete
sleep 20

# Run tests
docker-compose -f docker-compose.sira-community.app.yml --profile test run --rm test
```

### Run Tests in Existing Container

If app container is already running:

```bash
docker-compose -f docker-compose.sira-community.app.yml exec -e RAILS_ENV=test app \
  bundle exec rspec --format documentation
```

## Test Requirements

Tests require:
- ✅ Database connection (PostgreSQL with mTLS)
- ✅ Redis connection (with TLS)
- ✅ SSL certificates (mounted from host)
- ✅ Database migrations completed

## Test Failures

If tests fail:
- ❌ **Deployment is aborted**
- ❌ Error message is logged
- ❌ Exit code is non-zero
- ✅ No services are deployed

This ensures **fail-fast** behavior - broken code never reaches production.

## Test Output

Test output includes:
- Test execution progress
- Pass/fail status for each test
- Detailed error messages for failures
- Summary statistics

All output is logged to `deploy.log` for audit purposes.

## Integration Points

### build-and-deploy.sh

The `run_tests()` function:
1. Checks if `--skip-tests` flag is set
2. Starts migrate service if needed
3. Waits for migrations to complete
4. Runs test service
5. Aborts deployment if tests fail

### docker-compose.sira-community.app.yml

The `test` service:
- Uses same Docker image as `app` service
- Has same certificate mounts
- Uses test environment variables
- Runs once and exits (doesn't stay running)

## Best Practices

1. **Always run tests before deployment** - Don't use `--skip-tests` in production
2. **Fix test failures immediately** - Don't deploy broken code
3. **Review test output** - Check `deploy.log` for details
4. **Run tests locally first** - Catch issues before CI/CD

## Troubleshooting

### Tests fail with database connection errors
- Ensure `migrate` service completed successfully
- Check database credentials in `.env.community.app.local`
- Verify SSL certificates are mounted correctly

### Tests fail with Redis connection errors
- Check Redis is accessible from test container
- Verify Redis TLS certificates are mounted
- Check Redis password is set correctly

### Test service doesn't start
- Ensure Docker image is built: `docker-compose build test`
- Check `migrate` service is running: `docker-compose ps migrate`
- Verify test profile is used: `--profile test`

## Future Enhancements

Potential improvements:
- [ ] Parallel test execution
- [ ] Test coverage reporting
- [ ] Test result caching
- [ ] Integration with CI/CD pipelines
- [ ] Test result notifications



