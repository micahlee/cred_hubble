# CredHubble :full_moon_with_face::telescope::full_moon_with_face:

[![Build Status](https://travis-ci.org/tcdowney/cred_hubble.svg?branch=master)](https://travis-ci.org/tcdowney/cred_hubble)

Unofficial and **incomplete** Ruby client for storing and fetching credentials from a [Cloud Foundry CredHub](https://github.com/cloudfoundry-incubator/credhub) credential store.

The gem only supports endpoints detailed in the [usage](#usage) section for now, but eventually this library will let your Ruby app fetch secrets (e.g. database creds, Rails session secrets, AWS access keys, etc.) from CredHub at runtime, meaning you'll no longer need to store them in plaintext config files or in your app's environment.

That's the dream at least.

Right now this is just something I'm working on for fun since it's been a while since I've gotten to write a Ruby HTTP client. :grin:

## Installation

Add this line to your application's Gemfile:
There is a **very** alpha release available on Ruby Gems that I published to reserve the name, but it only supports the unauthenticated endpoints. A new release won't be published until I'm satisfied with the completeness of this library.

```ruby
gem 'cred_hubble', git: 'https://github.com/tcdowney/cred_hubble'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cred_hubble

## Authentication

To call endpoints that require authentication, you can authenticate with either an oAuth2 bearer token auth header or using mutual TLS (mTLS).
Here are some examples:

### Authenticating with an oAuth2 header
```ruby
> auth_header    = 'eyJhbGc.....OiJSUzI1NiIsI' # omit any 'bearer' portion
> credhub_client = CredHubble::Client.new_from_token_auth(
                     host: 'credhub.your-cloud-foundry.com',
                     port: '8844',
                     auth_header_token: auth_header
                   )
           
> credential = credhub_client.credential_by_id('f8d5a201-c3b9-48ae-8bc4-3b86b42210a1')
  => #<CredHubble::Resources::ValueCredential:0x0055f3811a5958 ...
```

### Authenticating with a client cert and key over mutual TLS
A typical Cloud Foundry application using CredHub will have access to two environment variables that contain these paths:
* `ENV['CF_INSTANCE_CERT']`
* `ENV['CF_INSTANCE_KEY']`

CredHub's CA certificate should already have been placed in the app instance's trusted cert store by Diego.

```ruby
> client_cert_path = '/etc/cf-instance-credentials/instance.crt' # ENV['CF_INSTANCE_CERT']
> client_key_path  = '/etc/cf-instance-credentials/instance.key' # ENV['CF_INSTANCE_KEY']
> credhub_client   = CredHubble::Client.new_from_mtls_auth(
                       host: 'credhub.your-cloud-foundry.com',
                       port: '8844',
                       client_cert_path: client_cert_path,
                       client_key_path: client_key_path
                     )
           
> credential = credhub_client.credential_by_id('f8d5a201-c3b9-48ae-8bc4-3b86b42210a1')
  => #<CredHubble::Resources::ValueCredential:0x0055f3811a5958 ...
```

### Specifying the CredHub CA certificate
If your CredHub server is using a self-signed (or otherwise non-trusted by your system) certificate you can supply CredHubble with the path to a local copy of the signing CA certificate.

```ruby
> auth_header     = 'eyJhbGc.....OiJSUzI1NiIsI' # omit any 'bearer' portion
> credhub_ca_path = '/some/path/certs/credhub_ca.crt'
> credhub_client  = CredHubble::Client.new_from_token_auth(
                      host: 'credhub.your-cloud-foundry.com',
                      port: '8844',
                      auth_header_token: auth_header,
                      ca_path: credhub_ca_path
                    )

> credential = credhub_client.credential_by_id('f8d5a201-c3b9-48ae-8bc4-3b86b42210a1')
  => #<CredHubble::Resources::ValueCredential:0x0055f3811a5958 ...
```

## Usage

CredHubble currently supports the following [CredHub endpoints](https://credhub-api.cfapps.io):

* **[GET Info](#get-info-and-get-health):** `/info`
* **[GET Health](#get-info-and-get-health):** `/health`
* **[GET Credential by ID](#get-credential-by-id):** `/api/v1/data/<credential-id>`
* **[GET Credentials by Name](#get-credentials-by-name):** `/api/v1/data?name=<credential-name>`
* **[GET Permissions by Credential Name](#get-permissions-by-credential-name):** `/api/v1/permissions?credential_name=<credential-name>`
* **[PUT Credential](#put-credential):** `/api/v1/data`
* **[POST Interpolate Credentials](#post-interpolate-credentials):** `/api/v1/interpolate`


### GET Info and GET Health
To try out the unauthenticated `info` and `health` endpoints, just do the following in your Ruby console:

```ruby
> credhub_client = CredHubble::Client.new(host: 'credhub.your-cloud-foundry.com', port: '8844')
           
> info = credhub_client.info
  => #<CredHubble::Resources::Info:0x00007fb36497a490 ...
  
> info.auth_server.url
  => "https://uaa.service.cf.internal:8443"
  
> health = credhub_client.health
  => #<CredHubble::Resources::Health:0x00007fb3648f0218 ...
  
> health.status
  => "UP"
```

For accessing endpoints that require authentication, simply create an authenticated client using one of the [authentication methods above](#authentication).

### GET Credential by ID
The `credential_by_id` method retrieves a single Credential resource from CredHub by ID.

```ruby
> credhub_client.credential_by_id('f297f736-dad2-4450-a7da-d3ff99f2030d')
  => #<CredHubble::Resources::ValueCredential:0x0055f3811a5958 ...
```

### GET Credentials by Name
Retrieves a collection of Credentials from CredHub for the given name. The `credentials_by_name` method will return all stored versions of the credential by default.
You can retrieve only the most recent version of the credential using the `current` option, or specify the number of versions to fetch with the `versions` option.

```ruby
> credentials = credhub_client.credentials_by_name('/admin-user-password')
  => #<CredHubble::Resources::CredentialCollection:0x00007f @data=[#<CredHubble::Resources::PasswordCredential:0x00004a ...
> credentials.count
  => 3
> credentials.map(&:id)
  => ["5298e0e4-c3f5-4c73-a156-9ffce4c137f5", "6980ec59-c7e6-449a-b525-298648cfe6a7", "3e709d6e-585c-4526-ac0d-fe99316f2255"]
  
> credentials = credhub_client.credentials_by_name('/admin-user-password', versions: 2)  
> credentials.count
  => 2
> credentials.map(&:id)
  => ["5298e0e4-c3f5-4c73-a156-9ffce4c137f5", "6980ec59-c7e6-449a-b525-298648cfe6a7"]
  
> credentials = credhub_client.credentials_by_name('/admin-user-password', current: true)
  => #<CredHubble::Resources::CredentialCollection:0x00007f @data=[#<CredHubble::Resources::PasswordCredential:0x00004a ...
> credentials.count
  => 1
> credentials.map(&:id)
  => ["5298e0e4-c3f5-4c73-a156-9ffce4c137f5"]
```

### GET Permissions by Credential Name

You can use the `permissions_by_credential_name` method to view the list of permissions for a given Credential.

```ruby
> client.permissions_by_credential_name('/credential-name')
  => #<CredHubble::Resources::PermissionCollection:0x00007fa231c12020
        @credential_name="/credential-name",
        @permissions=[
          #<CredHubble::Resources::Permission:0x00007fa231c11f08
              @actor="uaa-user:82f8ff1a-fcf8-4221-8d6b-0a1d579b6e47",
              @operations=["read", "write", "delete"]>,
          #<CredHubble::Resources::Permission:0x00007fa231c11e18
              @actor="mtls-app:18f64563-bcfe-4c88-bf73-05c9ad3654c8",
              @operations=["read"]>,
          #<CredHubble::Resources::Permission:0x00007fa231c11d00
              @actor="uaa-client:some_uaa_client",
              @operations=["read", "write", "delete", "read_acl", "write_acl"]>
        ]>
```


### PUT Credential
You can create new Credentials using the `put_credential` method. If you wish to replace an already existing Credential, simply pass
`overwrite: true` to the method and CredHub will create a new version of the Credential. Previous versions can be retrieved by using
the `credentials_by_name` method.

```ruby
> credential = CredHubble::Resources::UserCredential.new(
                    name: '/foundry-fred-user',
                    value: {username: 'foundy_fred', password: 's3cr3t'}
               )   
  => #<CredHubble::Resources::UserCredential:0x00007fb322caf3f0 @name="/foundry-fred-user", @value=#<CredHubble::Resources::UserValue ...
  
> credhub_client.put_credential(credential)
  => #<CredHubble::Resources::UserCredential:0x00007fb322d676d0
        @name="/foundry-fred-user",
        @value=#<CredHubble::Resources::UserValue:0x00007fb322d67478
                  @username="foundy_fred",
                  @password="s3cr3t",
                  @password_hash="$6$WwMLCRDr$Br54U0EnWD.A5i1EV9Cc7P16ZdjIBk0fFiYKghfOjW1MvL.vaXhWua.eGIbe0ziQIEP4s2OcGQpEEsc9ClFuA0">,
                  @id="92775889-71e0-41d1-a44c-93eb8fc5161a",
                  @type="user",
                  @version_created_at="2017-10-06T05:10:57Z">
             
> credential.value.password = 'foo bar'
  => "foo bar"
  
> credhub_client.put_credential(credential, overwrite: true)
  => #<CredHubble::Resources::UserCredential:0x00007fb322d676d0
        @name="/foundry-fred-user",
        @value=#<CredHubble::Resources::UserValue:0x00007fb322d67478
                  @username="foundy_fred",
                  @password="foo bar",
                  @password_hash="$6$WNAIgDrf$/.DxIfIg.8W6ZaIRjrjlOWS8FenigeWtswWr/D9edMbmSReYCzgG6VVdcdaftenq5VED3C8MJNVtDnNLF86SD.">,
                  @id="292ae24c-d7a3-4d8b-86a2-43630b83bafb",
                  @type="user",
                  @version_created_at="2017-10-06T05:11:43Z">
````

By default, only the creator of a Credential has access to read, write, delete, view its ACL, or updates its ACL. If you wish to
grant other parties various permissions for a given Credential, the `put_credential` method takes an optional `additional_permissions` array.

```ruby
> credential = CredHubble::Resources::UserCredential.new(
                    name: '/foundry-fred-user',
                    value: {username: 'foundy_fred', password: 's3cr3t'}
               )   
  => #<CredHubble::Resources::UserCredential:0x00007fb322caf3f0 @name="/foundry-fred-user", @value=#<CredHubble::Resources::UserValue ...
  
> permission = CredHubble::Resources::Permission.new(
                 actor: 'uaa-user:82f8ff1a-fcf8-4221-8d6b-0a1d579b6e47',
                 operations: ['write', 'read']
               )
  => #<CredHubble::Resources::Permission:0x00007f @actor="uaa-user:82f8ff1a-fcf8-4221-8d6b-0a1d579b6e47", @operations=["write", "read"]>
  
> credhub_client.put_credential(credential, additional_permissions: [permission])
  => #<CredHubble::Resources::UserCredential:0x00007fb322d676d0 ...
````

### POST Interpolate Credentials
Cloud Foundry applications traditionally access the credentials for any bound service instances through a `VCAP_SERVICES` environment variable.
Nowadays, however, some Service Brokers are CredHub aware and may choose to store service instance credentials in CredHub.
Apps bound to said services would only see `"credhub-ref"` key in place of actual credentials for that service instance. Here's an example `VCAP_SERVICES`:

```json
{
  "grid-config":[
    {
      "credentials":{
        "credhub-ref":"/grid-config/users/kflynn"
      },
      "label":"grid-config",
      "name":"config-server",
      "plan":"digital-frontier",
      "provider":null,
      "syslog_drain_url":null,
      "tags":[
        "configuration",
        "biodigital-jazz"
      ],
      "volume_mounts":[]
    }
  ],
  "encomSQL":[
    {
      "credentials":{
        "credhub-ref":"/encomSQL/db/users/63f7b900-982f-4f20-9213-6d270c3c58ea"
      },
        "label":"encom-db",
      "name":"encom-enterprise-db",
      "plan":"enterprise",
      "provider":null,
      "syslog_drain_url":null,
      "tags":[
        "database",
        "sql"
      ],
      "volume_mounts":[]
    }
  ]
}
```

Fortunately, CredHub supports an "interpolate" endpoint which allows an app to populate these values wholesale.
Here's how a CF application might use CredHubble's `interpolate_credentials` method to do that via mTLS authentication:

```ruby
> client_cert_path = ENV['CF_INSTANCE_CERT']
> client_key_path  = ENV['CF_INSTANCE_KEY']
> credhub_client   = CredHubble::Client.new_from_mtls_auth(
                       host: 'credhub.your-cloud-foundry.com',
                       port: '8844',
                       client_cert_path: client_cert_path,
                       client_key_path: client_key_path
                     )
           
> interpolated_services_json = credhub_client.interpolate_credentials(ENV['VCAP_SERVICES'])
  => '{
       "grid-config":[
         {
           "credentials":{
             "username":"kflynn",
             "password":"FlynnLives"
           },
           "label":"grid-config",
           "name":"config-server",
           "plan":"digital-frontier",
           "provider":null,
           "syslog_drain_url":null,
           "tags":[
             "configuration",
             "biodigital-jazz"
           ],
           "volume_mounts":[]
         }
       ],
       "encomSQL":[
         {
           "credentials":{
             "username":"grid-db-user",
             "password":"p4ssw0rd"
           },
           ... abridged ...
         }
       ]
     }'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tcdowney/cred_hubble.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
