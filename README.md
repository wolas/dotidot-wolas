# Improvements

## 1. Add Users and Authentication

Implement user authentication to restrict access to the scraping endpoint (`DataController#show`), ensuring only authorized users can make requests. Use token-based authentication for API compatibility.

**Proposed Changes**:
- Use the `devise` gem for user management and `devise-jwt` for JSON Web Token (JWT) authentication.
- Create a `User` model with fields for email, password, and JWT identifier, stored in the default Rails database.
- Add a `before_action :authenticate_user!` to `DataController` to require a valid JWT token for the `show` action.
- Provide endpoints for user registration (`POST /users/sign_up`), login (`POST /users/sign_in`), and token management.

**Benefits**:
- Secures the API, preventing unauthorized access.
- Enables tracking of scraping requests per user.
- JWT provides stateless, scalable authentication for API clients.

## 2. Suggest Similar Selectors When No Matches Found

Enhance the `Scrapper` class to suggest alternative CSS selectors when provided selectors (Eg: `.ratingCount`) return no matches, improving usability for users debugging their requests.

**Proposed Changes**:
- Modify `Scrapper#extract_fields` to check if a selector returns empty results.
- Use Nokogiri to analyze the HTML and suggest similar selectors based on:
    - Class names (Eg: suggest `.rating-count` for `.ratingCount`).
    - Tag names or parent/sibling relationships (Eg: suggest `div.rating`).
    - Fuzzy matching of class names using string similarity (Eg: with the `fuzzy_match` gem).
- Include suggestions in the `result` hash (Eg: `{ field_name: { value: "", suggestions: [".rating-count", "div.rating"] } }`) when no matches are found.
- Return suggestions only when the result is empty to avoid cluttering successful responses.

**Benefits**:
- Improves user experience by providing actionable feedback for failed selectors.
- Reduces trial-and-error when crafting selectors.
- Enhances debugging for unsuccessful scrape attempts.

**Considerations**:
- Limit the number of suggestions (Eg: top 3) to avoid performance overhead.

## 3. Asynchronous Scraping with Sidekiq

Offload scraping tasks to a background job to improve response times and handle slow or large scraping requests.

**Proposed Changes**:
- Use the `sidekiq` gem to create a `ScrapeJob` that executes `Scrapper#call`.
- Modify `DataController#show` to enqueue a `ScrapeJob` instead of calling `Scrapper` directly.
- Return a job ID in the response (Eg: `{ job_id: "123" }`) and provide a new endpoint (Eg: `GET /data/:job_id/status`) to check job status/results.
- Cache job results for 1 hour, maintaining the existing cache key structure (`requests/<md5_url>/<md5_fields>`).

**Benefits**:
- Reduces API response latency for slow scraping tasks.
- Handles timeouts and retries gracefully.
- Scales better for concurrent requests.

## 4. Rate Limiting

Add rate limiting to prevent abuse of the `DataController#show` endpoint, especially for authenticated users.

**Proposed Changes**:
- Use the `rack-attack` gem to limit requests per user or IP (Eg: 100 requests/hour).
- Configure limits in `config/initializers/rack_attack.rb`.
- Return `429 Too Many Requests` for exceeded limits with a descriptive error message.
- Allow higher limits for premium users (if implemented).

**Benefits**:
- Protects server resources from overuse.
- Ensures fair usage among authenticated users.
- Complements authentication for secure API usage.

## 5. Improved Error Handling

Enhance error handling in `Scrapper` and `DataController` to provide detailed, user-friendly error messages.

**Proposed Changes**:
- In `Scrapper#get_html`, categorize errors (Eg: network errors, invalid URLs, HTTP status codes) and return specific messages (Eg: "Invalid URL format", "Server returned 404").
- In `DataController#show`, return structured JSON errors (Eg: `{ error: { code: "invalid_url", message: "Invalid URL format" } }`) instead of raw `result`.
- Log errors to a service like Sentry using the `sentry-rails` gem.
- Handle edge cases like malformed HTML, invalid selectors, or missing `fields` parameters.

**Benefits**:
- Improves debugging for users and developers.
- Enhances API reliability and transparency.
- Facilitates error tracking in production.

## 6. Caching Enhancements

Optimize caching in `DataController#show` to reduce redundant scraping and improve performance.

**Proposed Changes**:
- Implement cache warming for frequently scraped URLs with Sidekiq jobs for example.
- Use Redis instead of `MemoryStore` for distributed caching in production via the `redis` gem.
- Add parameter to bypass caching entirely. Eg: `{ url: "test.com", bypass_cache: true }`

**Benefits**:
- Improves response times for common URLs.
- Scales better with Redis in production.

**Considerations**:
- Bypassing cache could be abused

## 7. Store previous scraps by user

Store the results of previous scraping operations performed by authenticated users in a NoSQL database (Redis or MongoDB) to enable analytics and historical data access. This allows users to retrieve past scrape results and supports analysis of scraping patterns.

**Proposed Changes**:
- Use the `redis` gem for Redis or `mongoid` gem for MongoDB to store scrape results.
- Create a data structure to store scrape results with fields: user ID (from authentication), URL, fields (CSS selectors), result (scraped data), error (if any), and timestamp.
- In `DataController#show`, after a successful scrape, save the `Scrapper` result to the chosen NoSQL database (Eg: Redis hash or MongoDB document).
- Add a new endpoint (Eg: `GET /data/history`) to retrieve a user’s previous scrape results, with optional filters for URL or date range.
- Ensure data is linked to the authenticated user (via `current_user` from Devise).

**Benefits**:
- Enables users to access their scrape history for review or reuse.
- Supports analytics (Eg: tracking frequently scraped URLs or selectors).
- Enhances debugging by storing error details from failed scrapes.
- Leverages NoSQL for flexible, scalable storage of unstructured scrape data.

**Considerations**:
- Implement pagination for the history endpoint to handle large datasets.
