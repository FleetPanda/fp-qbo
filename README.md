
# FpQbo

FpQbo is a stateless, production-ready Ruby gem for seamless QuickBooks Online API integration. It provides robust multi-tenancy support, token management, and a clean, framework-agnostic interface for CRUD, batch, and query operations.

## Features

- OAuth2 authentication and automatic token refresh
- CRUD operations for QuickBooks entities (Customer, Invoice, etc.)
- Batch API support
- SQL-like query builder
- Configurable environment (sandbox/production)
- Rate limit handling and retry logic
- Extensible, well-documented codebase

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fp_qbo', git: 'https://github.com/FleetPanda/fp-qbo'
```

Or install directly:

```bash
git clone https://github.com/FleetPanda/fp-qbo
cd fp-qbo
bundle install
```

## Setup & Configuration

Configure your credentials and environment in an initializer or before using the gem:

```ruby
FpQbo.configure do |config|
	config.client_id     = 'YOUR_CLIENT_ID'
	config.client_secret = 'YOUR_CLIENT_SECRET'
	config.environment   = :sandbox # or :production
	config.timeout       = 60
	config.retry_count   = 3
	# ...other options as needed
end
```

## Usage

### Initialize the Client

```ruby
client = FpQbo::Client.new(
	access_token:    'ACCESS_TOKEN',
	refresh_token:   'REFRESH_TOKEN',
	realm_id:        'REALM_ID',
	expires_at:      Time.now + 3600 # optional
)
```

### Query Example

```ruby
# Query all customers
response = client.query(entity: 'Customer')
customers = response.entity

# Query with conditions
response = client.query(entity: 'Customer', conditions: "Active = true", select: "DisplayName, Id", limit: 10)
```

### CRUD Operations

```ruby
# Create a customer
customer_data = {
	"DisplayName" => "Acme Inc.",
	"PrimaryEmailAddr" => { "Address" => "info@acme.com" }
}
response = client.create(entity: 'Customer', data: customer_data)

# Find a customer
response = client.find(entity: 'Customer', id: '12345')

# Update a customer
update_data = { "DisplayName" => "Acme Corp" }
response = client.update(entity: 'Customer', id: '12345', data: update_data)

# Delete a customer
response = client.delete(entity: 'Customer', id: '12345', sync_token: '2')
```

### Batch Operations

```ruby
batch_ops = [
	{ operation: 'create', entity: 'Customer', data: { "DisplayName" => "BatchCo" } },
	{ operation: 'query', entity: 'Customer', data: { "Query" => "SELECT * FROM Customer" } }
]
response = client.batch(batch_ops)
```

### Token Management

```ruby
if client.token_expires_soon?
	new_token_data = client.refresh_token!
	# Persist new_token_data as needed
end
```

### Error Handling

All API errors raise descriptive exceptions (see `lib/fp_qbo/errors.rb`). Handle errors as follows:

```ruby
begin
	client.query(entity: 'Customer')
rescue FpQbo::AuthenticationError => e
	puts "Auth error: #{e.message}"
rescue FpQbo::APIError => e
	puts "API error: #{e.error_detail}"
end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
