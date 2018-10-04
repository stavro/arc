Arc
===

[![Build Status](https://semaphoreci.com/api/v1/projects/7fc62b34-c895-475e-a3a6-671fefd0c017/480818/badge.svg)](https://semaphoreci.com/stavro/arc)

Arc is a flexible file upload library for Elixir with straightforward integrations for Amazon S3 and ImageMagick.

Browse the readme below, or jump to [a full example](#full-example).

## Content

- [Installation](#installation)
  - [Configuration](#configuration)
  - [Storage Providers](#storage-providers)
  - [Usage with Ecto](#usage-with-ecto)
- [Getting Started](#getting-started-defining-your-upload)
  - [Basics](#basics)
  - [Transformations](#transformations)
    - [ImageMagick Transformations](#imagemagick-transformations)
    - [FFmpeg Transformations](#ffmpeg-transformations)
    - [Complex Transformations](#complex-transformations)
  - [Asynchronous File Uploading](#asynchronous-file-uploading)
  - [Storage of Files](#storage-of-files)
    - [Local Configuration](#local-configuration)
    - [S3 Configuration](#s3-configuration)
    - [Storage Directory](#storage-directory)
    - [Specify multiple buckets](#specify-multiple-buckets)
    - [Specify multiple asset hosts](#specify-multiple-asset-hosts)
    - [Access Control Permissions](#access-control-permissions)
    - [S3 Object Headers](#s3-object-headers)
    - [File Validation](#file-validation)
    - [File Names](#file-names)
  - [Object Deletion](#object-deletion)
  - [URL Generation](#url-generation)
    - [Alternate S3 configuration example](#alternate-s3-configuration-example)
- [Full example](#full-example)

## Installation

Add the latest stable release to your `mix.exs` file, along with the required dependencies for `ExAws` if appropriate:

```elixir
defp deps do
  [
    arc: "~> 0.11.0",

    # If using Amazon S3:
    ex_aws: "~> 2.0",
    ex_aws_s3: "~> 2.0",
    hackney: "~> 1.6",
    poison: "~> 3.1",
    sweet_xml: "~> 0.6"
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

### Configuration

Arc expects certain properties to be configured at the application level:

```elixir
config :arc,
  storage: Arc.Storage.S3, # or Arc.Storage.Local
  bucket: {:system, "AWS_S3_BUCKET"} # if using Amazon S3
```

Along with any configuration necessary for ExAws.

### Storage Providers
Arc ships with integrations for Local Storage and S3.  Alternative storage providers may be supported by the community:

* **Rackspace** - https://github.com/lokalebasen/arc_rackspace
* **Manta** - https://github.com/onyxrev/arc_manta
* **OVH** - https://github.com/stephenmoloney/arc_ovh
* **Google Cloud Storage** - https://github.com/martide/arc_gcs
* **Microsoft Azure Storage** - https://github.com/phil-a/arc_azure

### Usage with Ecto

Arc comes with a companion package for use with Ecto.  If you intend to use Arc with Ecto, it is highly recommended you also add the [`arc_ecto`](https://github.com/stavro/arc_ecto) dependency.  Benefits include:

  * Changeset integration
  * Versioned urls for cache busting (`.../thumb.png?v=63601457477`)

# Getting Started: Defining your Upload

Arc requires a **definition module** which contains the relevant configuration to store and retrieve your files.

This definition module contains relevant functions to determine:
  * Optional transformations of the uploaded file
  * Where to put your files (the storage directory)
  * What to name your files
  * How to secure your files (private? Or publicly accessible?)
  * Default placeholders

To start off, generate an attachment definition:

```bash
mix arc.g avatar
```

This should give you a basic file in:

```
web/uploaders/avatar.ex
```

Check this file for descriptions of configurable options.

## Basics

There are two supported use-cases of Arc currently:

  1. As a general file store, or
  2. As an attachment to another model (the attached model is referred to as a `scope`)

The upload definition file responds to `Avatar.store/1` which accepts either:

  * A path to a local file
  * A path to a remote `http` or `https` file
  * A map with a filename and path keys (eg, a `%Plug.Upload{}`)
  * A map with a filename and binary keys (eg, `%{filename: "image.png", binary: <<255,255,255,...>>}`)
  * A two-tuple consisting of one of the above file formats as well as a scope object.

Example usage as general file store:

```elixir
# Store any locally accessible file
Avatar.store("/path/to/my/file.png") #=> {:ok, "file.png"}

# Store any remotely accessible file
Avatar.store("http://example.com/file.png") #=> {:ok, "file.png"}

# Store a file directly from a `%Plug.Upload{}`
Avatar.store(%Plug.Upload{filename: "file.png", path: "/a/b/c"}) #=> {:ok, "file.png"}

# Store a file from a connection body
{:ok, data, _conn} = Plug.Conn.read_body(conn)
Avatar.store(%{filename: "file.png", binary: data})
```

Example usage as a file attached to a `scope`:

```elixir
scope = Repo.get(User, 1)
Avatar.store({%Plug.Upload{}, scope}) #=> {:ok, "file.png"}
```

This scope will be available throughout the definition module to be used as an input to the storage parameters (eg, store files in `/uploads/#{scope.id}`).

## Transformations

Arc can be used to facilitate transformations of uploaded files via any system executable.  Some common operations you may want to take on uploaded files include resizing an uploaded avatar with ImageMagick or extracting a still image from a video with FFmpeg.

To transform an image, the definition module must define a `transform/2` function which accepts a version atom and a tuple consisting of the uploaded file and corresponding scope.

This transform handler accepts the version atom, as well as the file/scope argument, and is responsible for returning one of the following:
  * `:noaction` - The original file will be stored as-is.
  * `:skip` - Nothing will be stored for the provided version.
  * `{executable, args}` - The `executable` will be called with `System.cmd` with the format `#{original_file_path} #{args} #{transformed_file_path}`.
  * `{executable, fn(input, output) -> args end}` - If your executable expects arguments in a format other than the above, you may supply a function to the conversion tuple which will be invoked to generate the arguments. The arguments can be returned as a string (e.g. – `" #{input} -strip -thumbnail 10x10 #{output}"`) or a list (e.g. – `[input, "-strip", "-thumbnail", "10x10", output]`) for even more control.
  * `{executable, args, output_extension}` - If your transformation changes the file extension (eg, converting to `png`), then the new file extension must be explicit.

### ImageMagick transformations

As images are one of the most commonly uploaded filetypes, Arc has a recommended integration with ImageMagick's `convert` tool for manipulation of images.  Each upload definition may specify as many versions as desired, along with the corresponding transformation for each version.

The expected return value of a `transform` function call must either be `:noaction`, in which case the original file will be stored as-is, `:skip`, in which case nothing will be stored, or `{:convert, transformation}` in which the original file will be processed via ImageMagick's `convert` tool with the corresponding transformation parameters.

The following example stores the original file, as well as a squared 100x100 thumbnail version which is stripped of comments (eg, GPS coordinates):

```elixir
defmodule Avatar do
  use Arc.Definition

  @versions [:original, :thumb]

  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100"}
  end
end
```

Other examples:

```elixir
# Change the file extension through ImageMagick's `format` parameter:
{:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100 -format png", :png}

# Take the first frame of a gif and process it into a square jpg:
{:convert, fn(input, output) -> "#{input}[0] -strip -thumbnail 100x100^ -gravity center -extent 100x100 -format jpg #{output}", :jpg}
```

For more information on defining your transformation, please consult [ImageMagick's convert documentation](http://www.imagemagick.org/script/convert.php).

> **Note**: Keep this transformation function simple and deterministic based on the version, file name, and scope object. The `transform` function is subsequently called during URL generation, and the transformation is scanned for the output file format.  As such, if you conditionally format the image as a `png` or `jpg` depending on the time of day, you will be displeased with the result of Arc's URL generation.

> **System Resources**: If you are accepting arbitrary uploads on a public site, it may be prudent to add system resource limits to prevent overloading your system resources from malicious or nefarious files.  Since all processing is done directly in ImageMagick, you may pass in system resource restrictions through the [-limit](http://www.imagemagick.org/script/command-line-options.php#limit) flag.  One such example might be: `-limit area 10MB -limit disk 100MB`.

### FFmpeg transformations

Common transformations of uploaded videos can be also defined through your definition module:

```elixir
# To take a thumbnail from a video:
{:ffmpeg, fn(input, output) -> "-i #{input} -f jpg #{output}" end, :jpg}

# To convert a video to an animated gif
{:ffmpeg, fn(input, output) -> "-i #{input} -f gif #{output}" end, :gif}
```

### Complex Transformations
`Arc` requires the output of your transformation to be located at a predetermined path.  However, the transformation may be done completely outside of `Arc`. For fine-grained transformations, you should create an executable wrapper in your $PATH (eg. bash script) which takes these proper arguments, runs your transformation, and then moves the file into the correct location.

For example, to use `soffice` to convert a doc to an html file, you should place the following bash script in your $PATH:

```bash
#!/usr/bin/env sh

# `soffice` doesn't allow for output file path option, and arc can't find the
# temporary file to process and copy. This script has a similar argument list as
# what arc expects. See https://github.com/stavro/arc/issues/77.

set -e
set -o pipefail

function convert {
    soffice \
        --headless \
        --convert-to html \
        --outdir $TMPDIR \
        "$1"
}

function filter_new_file_name {
    awk -F$TMPDIR '{print $2}' \
    | awk -F" " '{print $1}' \
    | awk -F/ '{print $2}'
}

converted_file_name=$(convert "$1" | filter_new_file_name)

cp $TMPDIR/$converted_file_name "$2"
rm $TMPDIR/$converted_file_name
```

And perform the transformation as such:


```elixir
def transform(:html, _) do
  {:soffice_wrapper, fn(input, output) -> [input, output] end, :html}
end
```

## Asynchronous File Uploading

If you specify multiple versions in your definition module, each version is processed and stored concurrently as independent Tasks.  To prevent an overconsumption of system resources, each Task is given a specified timeout to wait, after which the process will fail.  By default this is `15 seconds`.

If you wish to change the time allocated to version transformation and storage, you may add a configuration parameter:

```elixir
config :arc,
  :version_timeout, 15_000 # milliseconds
```

To disable asynchronous processing, add `@async false` to your upload definition.

## Storage of files

Arc currently supports Amazon S3 and local destinations for file uploads.

### Local Configuration

To store your attachments locally, override the `__storage` function in your definition module to `Arc.Storage.Local`. You may wish to optionally override the storage directory as well, as outlined below.

```elixir
defmodule Avatar do
  use Arc.Definition
  def __storage, do: Arc.Storage.Local # Add this
end
```

### S3 Configuration

[ExAws](https://github.com/CargoSense/ex_aws) is used to support Amazon S3.

To store your attachments in Amazon S3, you'll need to provide a bucket destination in your application config:

```elixir
config :arc,
  bucket: "uploads"
```

You may also set the bucket from an environment variable:

```elixir
config :arc,
  bucket: {:system, "S3_BUCKET"}
```

In addition, ExAws must be configured with the appropriate Amazon S3 credentials.

ExAws has by default the following configuration (which you may override if you wish):

```elixir
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]
```

This means it will first look for the AWS standard AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables, and fall back using instance meta-data if those don't exist. You should set those environment variables to your credentials, or configure an instance that this library runs on to have an iam role.

### Storage Directory

**Configuration Option**

* `arc[:storage_dir]` - The storage directory to place files. Defaults to `uploads`, but can be overwritten via configuration options `:storage_dir`

```elixir
config :arc,
  storage_dir: "my/dir"
```

The storage dir can also be overwritten on an individual basis, in each separate definition. A common pattern for user profile pictures is to store each user's uploaded images in a separate subdirectory based on their primary key:

```elixir
def storage_dir(version, {file, scope}) do
  "uploads/users/avatars/#{scope.id}"
end
```


> **Note**: If you are "attaching" a file to a record on creation (eg, while inserting the record at the same time), then you cannot use the model's `id` as a path component.  You must either (1) use a different storage path format, such as UUIDs, or (2) attach and update the model after an id has been given.

> **Note**: The storage directory is used for both local filestorage (as the relative or absolute directory), and S3 storage, as the path name (not including the bucket).

### Specify multiple buckets

Arc lets you specify a bucket on a per definition basis. In case you want to use
multiple buckets, you can specify a bucket in the uploader definition file
like this:

```elixir
def bucket, do: :some_custom_bucket_name
```

### Specify multiple asset hosts

Arc lets you specify an asset host on a per definition basis. In case you want to use
multiple hosts, you can specify an asset_host in the uploader definition file
like this:

```elixir
def asset_host, do: "https://example.com"
```

### Access Control Permissions

Arc defaults all uploads to `private`.  In cases where it is desired to have your uploads public, you may set the ACL at the module level (which applies to all versions):

```elixir
@acl :public_read
```

Or you may have more granular control over each version.  As an example, you may wish to explicitly only make public a thumbnail version of the file:

```elixir
def acl(:thumb, _), do: :public_read
```

Supported access control lists for Amazon S3 are:

| ACL                          | Permissions Added to ACL                                                                                                                |
|------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `:private`                   | Owner gets `FULL_CONTROL`. No one else has access rights (default).                                                                     |
| `:public_read`               | Owner gets `FULL_CONTROL`. The `AllUsers` group gets READ access.                                                                       |
| `:public_read_write`         | Owner gets `FULL_CONTROL`. The `AllUsers` group gets `READ` and `WRITE` access. Granting this on a bucket is generally not recommended. |
| `:authenticated_read`        | Owner gets `FULL_CONTROL`. The `AuthenticatedUsers` group gets `READ` access.                                                           |
| `:bucket_owner_read`         | Object owner gets `FULL_CONTROL`. Bucket owner gets `READ` access.                                                                      |
| `:bucket_owner_full_control` | Both the object owner and the bucket owner get `FULL_CONTROL` over the object.                                                          |

For more information on the behavior of each of these, please consult Amazon's documentation for [Access Control List (ACL) Overview](https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html).

### S3 Object Headers

The definition module may specify custom headers to pass through to S3 during object creation.  The available custom headers include:
  *  :cache_control
  *  :content_disposition
  *  :content_encoding
  *  :content_length
  *  :content_type
  *  :expect
  *  :expires
  *  :storage_class
  *  :website_redirect_location
  *  :encryption (set to "AES256" for encryption at rest)


As an example, to explicitly specify the content-type of an object, you may define a `s3_object_headers/2` function in your definition, which returns a Keyword list, or Map of desired headers.

```elixir
def s3_object_headers(version, {file, scope}) do
  [content_type: MIME.from_path(file.file_name)] # for "image.png", would produce: "image/png"
end
```

### File Validation

While storing files on S3 (rather than your harddrive) eliminates some malicious attack vectors, it is strongly encouraged to validate the extensions of uploaded files as well.

Arc delegates validation to a `validate/1` function with a tuple of the file and scope.  As an example, to validate that an uploaded file conforms to popular image formats, you may use:

```elixir
defmodule Avatar do
  use Arc.Definition
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()
    Enum.member?(@extension_whitelist, file_extension)
  end
end
```

Any uploaded file failing validation will return `{:error, :invalid_file}` when passed through to `Avatar.store`.

### File Names

It may be undesirable to retain original filenames (eg, it may contain personally identifiable information, vulgarity, vulnerabilities with Unicode characters, etc).

You may specify the destination filename for uploaded versions through your definition module.

A common pattern is to combine directories scoped to a particular model's primary key, along with static filenames. (eg: `user_avatars/1/thumb.png`)

Examples:

```elixir
# To retain the original filename, but prefix the version and user id:
def filename(version, {file, scope}) do
  file_name = Path.basename(file.file_name, Path.extname(file.file_name))
  "#{scope.id}_#{version}_#{file_name}"
end

# To make the destination file the same as the version:
def filename(version, _), do: version
```

## Object Deletion

After an object is stored through Arc, you may optionally remove it.  To remove a stored object, pass the same path identifier and scope from which you stored the object.

Example:

```elixir
# Without a scope:
{:ok, original_filename} = Avatar.store("/Images/me.png")
:ok = Avatar.delete(original_filename)

# With a scope:
user = Repo.get! User, 1
{:ok, original_filename} = Avatar.store({"/Images/me.png", user})
:ok = Avatar.delete({original_filename, user})
# or
user = Repo.get!(User, 1)
{:ok, original_filename} = Avatar.store({"/Images/me.png", user})
user = Repo.get!(User, 1)
:ok = Avatar.delete({user.avatar, user})
```

## Url Generation

Saving your files is only the first half of any decent storage solution.  Straightforward access to your uploaded files is equally as important as storing them in the first place.

Often times you will want to regain access to the stored files.  As such, `Arc` facilitates the generation of urls.

```elixir
# Given some user record
user = %{id: 1}

Avatar.store({%Plug.Upload{}, user}) #=> {:ok, "selfie.png"}

# To generate a regular, unsigned url (defaults to the first version):
Avatar.url({"selfie.png", user}) #=> "https://bucket.s3.amazonaws.com/uploads/1/original.png"

# To specify the version of the upload:
Avatar.url({"selfie.png", user}, :thumb) #=> "https://bucket.s3.amazonaws.com/uploads/1/thumb.png"

# To generate a signed url:
Avatar.url({"selfie.png", user}, :thumb, signed: true) #=> "https://bucket.s3.amazonaws.com/uploads/1/thumb.png?AWSAccessKeyId=AKAAIPDF14AAX7XQ&Signature=5PzIbSgD1V2vPLj%2B4WLRSFQ5M%3D&Expires=1434395458"

# To generate urls for all versions:
Avatar.urls({"selfie.png", user}) #=> %{original: "https://.../original.png", thumb: "https://.../thumb.png"}
```

**Default url**

In cases where a placeholder image is desired when an uploaded file is not present, Arc allows the definition of a default image to be returned gracefully when requested with a `nil` file.

```elixir
def default_url(version) do
  MyApp.Endpoint.url <> "/images/placeholders/profile_image.png"
end

Avatar.url(nil) #=> "http://example.com/images/placeholders/profile_image.png"
Avatar.url({nil, scope}) #=> "http://example.com/images/placeholders/profile_image.png"
```

**Virtual Host**

To support AWS regions other than US Standard, it may be required to generate urls in the [`virtual_host`](http://docs.aws.amazon.com/AmazonS3/latest/dev/VirtualHosting.html) style.  This will generate urls in the style: `https://#{bucket}.s3.amazonaws.com` instead of `https://s3.amazonaws.com/#{bucket}`.

To use this style of url generation, your bucket name must be DNS compliant.

This can be enabled with:

```elixir
config :arc,
  virtual_host: true
```

> When using virtual hosted–style buckets with SSL, the SSL wild card certificate only matches buckets that do not contain periods. To work around this, use HTTP or write your own certificate verification logic.


**Asset Host**

You may optionally specify an asset host rather than using the default `bucket.s3.amazonaws.com` format.

In your application configuration, you'll need to provide an `asset_host` value:

```elixir
config :arc,
  asset_host: "https://d3gav2egqolk5.cloudfront.net", # For a value known during compilation
  asset_host: {:system, "ASSET_HOST"} # For a value not known until runtime
```

### Alternate S3 configuration example
If you are using a region other than US-Standard, it is necessary to specify the correct configuration for `ex_aws`.  A full example configuration for both arc and ex_aws is as follows:

```
config :arc,
  bucket: "my-frankfurt-bucket"

config :ex_aws,
  access_key_id: "my_access_key_id",
  secret_access_key: "my_secret_access_key",
  region: "eu-central-1",
  s3: [
    scheme: "https://",
    host: "s3.eu-central-1.amazonaws.com",
    region: "eu-central-1"
  ]
```

> For your host configuration, please examine the approved [AWS Hostnames](http://docs.aws.amazon.com/general/latest/gr/rande.html).  There are often multiple hostname formats for AWS regions, and it will not work unless you specify the correct one.


# Full Example

```elixir
defmodule Avatar do
  use Arc.Definition

  @versions [:original, :thumb]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def acl(:thumb, _), do: :public_read

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname |> String.downcase
    Enum.member?(@extension_whitelist, file_extension)
  end

  def transform(:thumb, _) do
    {:convert, "-thumbnail 100x100^ -gravity center -extent 100x100 -format png", :png}
  end

  def filename(version, _) do
    version
  end

  def storage_dir(_, {file, user}) do
    "uploads/avatars/#{user.id}"
  end

  def default_url(:thumb) do
    "https://placehold.it/100x100"
  end
end

# Given some current_user record
current_user = %{id: 1}

# Store any accessible file
Avatar.store({"/path/to/my/selfie.png", current_user}) #=> {:ok, "selfie.png"}

# ..or store directly from the `params` of a file upload within your controller
Avatar.store({%Plug.Upload{}, current_user}) #=> {:ok, "selfie.png"}

# and retrieve the url later
Avatar.url({"selfie.png", current_user}, :thumb) #=> "https://s3.amazonaws.com/bucket/uploads/avatars/1/thumb.png"
```

## Roadmap

Contributions are welcome.  Here is my current roadmap:

  * Ease migration for version (or acl) changes
  * Alternative storage destinations (eg, Filesystem)
  * Solidify public API

## Contribution

Open source contributions are welcome.  All pull requests must have corresponding unit tests.

To execute all tests locally, make sure the following system environment variables are set prior to running tests (if you wish to test `s3_test.exs`)

  * `ARC_TEST_BUCKET`
  * `ARC_TEST_S3_KEY`
  * `ARC_TEST_S3_SECRET`

Then execute `mix test`.

## License

Copyright 2015 Sean Stavropoulos

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
