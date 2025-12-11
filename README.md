# ActiveStorage::Gridfs

This gem is an adapter for MongoDB's GridFS use with ActiveStorage. It allows GridFS to be used similarly to AWS S3 or Google Cloud Storage Service for file storage and querying through ActiveStorage.

** Please note that Active Storage is not compatible with `mongoid` at this time. **

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add active_storage-gridfs
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install active_storage-gridfs
```

## Usage

Set up Active Storage in your project using the instructions detailed [here](https://guides.rubyonrails.org/active_storage_overview.html). In [step 2](https://guides.rubyonrails.org/active_storage_overview.html#setup), add the following to your `config/storage.yml`:

```yml
gridfs:
  service: GridFS
  database: your_database_name
  uri: mongodb://localhost:27017 # or wherever your database is hosted
  bucket: fs  # optional, defaults to "fs"
```

For each environment you would like to use GridFS (development/test/production), add the following to `config/environments/[ENVIRONMENT].rb`:

```rb
# Store files in GridFS.
config.active_storage.service = :gridfs
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. 

To set up the dummy project for testing, run:

```sh
cd test/dummy
bin/rails active_storage:install
bin/rails db:migrate
```

Then, run `bundle exec rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
