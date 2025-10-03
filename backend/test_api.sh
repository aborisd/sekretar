#!/bin/bash

# Backend API Testing Script
# Tests all endpoints: health, auth, sync

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Base URL
BASE_URL="${BASE_URL:-http://localhost:8000}"

# Test results array
declare -a FAILED_TEST_NAMES

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}AI Calendar Backend API Tests${NC}"
echo -e "${BLUE}================================${NC}\n"

# Helper function to run test
run_test() {
    local test_name="$1"
    local expected_status="$2"
    shift 2
    local curl_cmd="$@"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -e "${YELLOW}Test $TOTAL_TESTS:${NC} $test_name"

    # Run curl and capture response + status
    response=$(eval "$curl_cmd" 2>&1)
    status=$?

    if [ $status -eq 0 ]; then
        # Check if response contains expected status code
        if echo "$response" | grep -q "\"$expected_status\"" || \
           echo "$response" | grep -q "HTTP.*$expected_status" || \
           [ "$expected_status" = "ANY" ]; then
            echo -e "${GREEN}✓ PASSED${NC}\n"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ FAILED${NC}"
            echo -e "Response: $response\n"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            FAILED_TEST_NAMES+=("$test_name")
        fi
    else
        echo -e "${RED}✗ FAILED (curl error)${NC}"
        echo -e "Error: $response\n"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name")
    fi
}

# 1. Health Check
run_test "Health Check" "healthy" \
    "curl -s -X GET '$BASE_URL/health'"

# 2. Root Endpoint
run_test "Root Endpoint" "AI Calendar Backend API" \
    "curl -s -X GET '$BASE_URL/'"

# 3. API Docs (check if available)
run_test "API Docs Available" "200" \
    "curl -s -o /dev/null -w '%{http_code}' '$BASE_URL/api/docs'"

echo -e "${BLUE}--- Authentication Tests ---${NC}\n"

# 4. Register User
RANDOM_EMAIL="test_$(date +%s)@example.com"
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$RANDOM_EMAIL\", \"password\": \"testpass123\"}")

if echo "$REGISTER_RESPONSE" | grep -q "access_token"; then
    echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Register User"
    echo -e "${GREEN}✓ PASSED${NC}\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))

    # Extract token
    TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"user_id":"[^"]*"' | cut -d'"' -f4)

    echo -e "${GREEN}Token received:${NC} ${TOKEN:0:20}..."
    echo -e "${GREEN}User ID:${NC} $USER_ID\n"
else
    echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Register User"
    echo -e "${RED}✗ FAILED${NC}"
    echo -e "Response: $REGISTER_RESPONSE\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILED_TEST_NAMES+=("Register User")
    TOKEN=""
fi

# 5. Login User
if [ ! -z "$RANDOM_EMAIL" ]; then
    LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"email\": \"$RANDOM_EMAIL\", \"password\": \"testpass123\"}")

    if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Login User"
        echo -e "${GREEN}✓ PASSED${NC}\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Login User"
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "Response: $LOGIN_RESPONSE\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("Login User")
    fi
fi

# 6. Duplicate Email Registration (should fail)
DUPLICATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$RANDOM_EMAIL\", \"password\": \"test\"}")

if echo "$DUPLICATE_RESPONSE" | grep -q "already registered"; then
    echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Duplicate Email Registration (should fail)"
    echo -e "${GREEN}✓ PASSED${NC}\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Duplicate Email Registration (should fail)"
    echo -e "${RED}✗ FAILED (should reject duplicate)${NC}"
    echo -e "Response: $DUPLICATE_RESPONSE\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILED_TEST_NAMES+=("Duplicate Email Registration")
fi

# 7. Apple Sign In
APPLE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/apple" \
    -H "Content-Type: application/json" \
    -d "{\"apple_id\": \"001234.test.apple.com\", \"email\": \"apple_$(date +%s)@example.com\", \"full_name\": \"Test User\"}")

if echo "$APPLE_RESPONSE" | grep -q "access_token"; then
    echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Apple Sign In"
    echo -e "${GREEN}✓ PASSED${NC}\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Apple Sign In"
    echo -e "${RED}✗ FAILED${NC}"
    echo -e "Response: $APPLE_RESPONSE\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILED_TEST_NAMES+=("Apple Sign In")
fi

echo -e "${BLUE}--- Sync Tests ---${NC}\n"

if [ ! -z "$TOKEN" ]; then
    # 8. Sync Status
    STATUS_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v1/sync/status" \
        -H "Authorization: Bearer $TOKEN")

    if echo "$STATUS_RESPONSE" | grep -q "user_id"; then
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Sync Status"
        echo -e "${GREEN}✓ PASSED${NC}\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Sync Status"
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "Response: $STATUS_RESPONSE\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("Sync Status")
    fi

    # 9. Push Task
    TASK_ID="$(uuidgen)"
    PUSH_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/sync/push" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"tasks\": [{
                \"id\": \"$TASK_ID\",
                \"title\": \"Test task from script\",
                \"notes\": \"Created by test_api.sh\",
                \"due_date\": null,
                \"priority\": \"medium\",
                \"completed_at\": null,
                \"is_deleted\": false,
                \"version\": 1
            }]
        }")

    if echo "$PUSH_RESPONSE" | grep -q "success"; then
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Push Task"
        echo -e "${GREEN}✓ PASSED${NC}"
        echo -e "${GREEN}Task ID:${NC} $TASK_ID\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Push Task"
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "Response: $PUSH_RESPONSE\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("Push Task")
    fi

    # 10. Pull Tasks
    PULL_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v1/sync/pull" \
        -H "Authorization: Bearer $TOKEN")

    if echo "$PULL_RESPONSE" | grep -q "$TASK_ID"; then
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Pull Tasks (verify pushed task)"
        echo -e "${GREEN}✓ PASSED${NC}\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Pull Tasks (verify pushed task)"
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "Response: $PULL_RESPONSE\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("Pull Tasks")
    fi

    # 11. Conflict Resolution (push old version)
    CONFLICT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/sync/push" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"tasks\": [{
                \"id\": \"$TASK_ID\",
                \"title\": \"Updated on client\",
                \"notes\": \"Should conflict\",
                \"priority\": \"high\",
                \"version\": 1
            }]
        }")

    if echo "$CONFLICT_RESPONSE" | grep -q "conflicts"; then
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Conflict Resolution"
        echo -e "${GREEN}✓ PASSED${NC}\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Conflict Resolution"
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "Response: $CONFLICT_RESPONSE\n"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("Conflict Resolution")
    fi
else
    echo -e "${YELLOW}Skipping sync tests (no auth token)${NC}\n"
fi

echo -e "${BLUE}--- Error Handling Tests ---${NC}\n"

# 12. Invalid Token
INVALID_TOKEN_RESPONSE=$(curl -s -X GET "$BASE_URL/api/v1/sync/pull" \
    -H "Authorization: Bearer invalid-token-12345" \
    -w "\nHTTP_STATUS:%{http_code}")

if echo "$INVALID_TOKEN_RESPONSE" | grep -q "HTTP_STATUS:401"; then
    echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Invalid Token (should return 401)"
    echo -e "${GREEN}✓ PASSED${NC}\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}Test $((TOTAL_TESTS + 1)):${NC} Invalid Token (should return 401)"
    echo -e "${RED}✗ FAILED${NC}"
    echo -e "Response: $INVALID_TOKEN_RESPONSE\n"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILED_TEST_NAMES+=("Invalid Token")
fi

# Summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
    echo -e "\n${RED}Failed Tests:${NC}"
    for test_name in "${FAILED_TEST_NAMES[@]}"; do
        echo -e "  - $test_name"
    done
else
    echo -e "${GREEN}Failed:       $FAILED_TESTS${NC}"
fi

SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "\nSuccess Rate: ${SUCCESS_RATE}%"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  Some tests failed. Please check the output above.${NC}"
    exit 1
fi
