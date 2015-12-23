# Changelog

## v0.3.0 (2016-01-22)
  * (Enhancement) Introduce `Definition.delete/2`

> While there is no strict backwards incompatibility with the public API, a number of users have been using Arc.Storage.S3.delete as a public API due to a lack of a fully supported delete method.  This internal method has now changed slightly, thus prompting more than a patch release.

## v0.2.3 (2016-01-22)
  * (Enhancement) Allow specifying custom s3 object headers through the definition module via `s3_object_headers/2`.

## v0.2.2 (12-14-2015)
  * (Enhancement) Allow the version transformation and storage timeout to be specified in configuration `config :arc, version_timeout: 15_000`.

## v0.2.1 (12-11-2015)
  * (Bugfix) Raise `Arc.ConvertError` if ImageMagick's `convert` tool exits unsuccessfully.

## v0.2.0 (12-11-2015)
  * (Breaking Change) Erlcloud has been removed in favor of ExAws.
  * (Enhancement) Added a configuration parameter to generate urls in the `virtual_host` style.

### Upgrade Instructions
Since `erlcloud` has been removed from `arc`, you must also remove it from your dependency graph as well as your application list. In its place, add `ex_aws` and `httpoison` to your dependencies as well as application list. Next, remove the aws credential configuration from arc:

```elixir
# BEFORE
config :arc,
  access_key_id: "###",		
  secret_access_key: "###",		
  bucket: "uploads"

#AFTER
config :arc,
  bucket: "uploads"

# (this is the default ex_aws config... if your keys are not in environment variables you can override it here)
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]
```

Read more about how ExAws manages configuration [here](https://github.com/CargoSense/ex_aws).

## v0.1.4 (11-10-2015)
  * (Enhancement: Local Storage) Filenames which contain path separators will flatten out as expected prior to moving copying the file to its destination.

## v0.1.3 (09-15-2015)

  * (Enhancement: Url Generation) `default_url/2` introduced to definition module which passes the given scope as the second parameter.  Backwards compatibility is maintained for `default_url/1`.

## v0.1.2 (09-08-2015)

  * (Bugfix: Storage) Bugfix for referencing atoms in the file name.

## v0.1.1

  * (Enhancement: Storage) Add the local filesystem as a storage option.
