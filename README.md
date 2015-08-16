Arc
===

[![Build Status](https://semaphoreci.com/api/v1/projects/7fc62b34-c895-475e-a3a6-671fefd0c017/480818/badge.svg)](https://semaphoreci.com/stavro/arc)

Arc is a flexible file upload library for Elixir with straightforward integrations for Amazon S3 and ImageMagick.

Browse the readme below, or jump to [a full example](#full-example).

## Installation

Add the latest stable release to your `mix.exs` file:

```elixir
defp deps do
  [
    {:arc, "~> 0.1.0"}
  ]
end
```

and add `erlcloud` as an application startup dependency in your application's `mix.exs` file:

```elixir
def application do
  [
    mod: { MyApp, [] },
    applications: [
      :other_app_dependencies,
      :erlcloud
    ]
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

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
  * How to secure your files (private? Or publically accessible?)
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

  * A path to a file
  * A map with a filename and path keys (eg, a `%Plug.Upload{}`)
  * A two-tuple consisting of one of the above file formats as well as a scope object.

Example usage as general file store:

```elixir
# Store any accessible file path
Avatar.store("/path/to/my/file.png") #=> {:ok, "file.png"}

# Store a file directly from a `%Plug.Upload{}`
Avatar.store(%Plug.Upload{filename: "file.png", path: "/a/b/c"}) #=> {:ok, "file.png"}
```

Example usage as a file attached to a `scope`:

```elixir
scope = Repo.get(User, 1)

Avatar.store({%Plug.Upload{}, scope}) #=> {:ok, "file.png"}
```

This scope will be available throughout the definition module to be used as an input to the storage parameters (eg, store files in `/uploads/#{scope.id}`).

## Image Transformations

As images are one of the most commonly uploaded filetypes, Arc has a convenient integration with ImageMagick's `convert` tool for manipulation of images.  Each upload definition may specify as many versions as desired, along with the corresponding transformation for each version.

To transform an image, the definition module must define a `transform/2` function which accepts a version atom and a tuple consisting of the uploaded file and corresponding scope.

The expected return value of a `transform` function call must either be `{:noaction}`, in which case the original file will be stored as-is, or `{:convert, transformation}` in which the original file will be processed via ImageMagick's `convert` tool with the corresponding transformation parameters.

Example:

```elixir
defmodule Avatar do
  use Arc.Definition

  @versions [:original, :thumb]

  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100 -format png"}
  end
end
```

The example above stores the original file, as well as a squared 100x100 thumbnail version which is stripped of comments (eg, GPS coordinates).

For more information on defining your transformation, please consult [ImageMagick's convert documentation](http://www.imagemagick.org/script/convert.php).

> **Note**: Keep this transformation function simple and deterministic based on the version, file name, and scope object. The `transform` function is subsequently called during URL generation, and the transformation is scanned for the output file format.  As such, if you conditionally format the image as a `png` or `jpg` depending on the time of day, you will be displeased with the result of Arc's URL generation.

## Storage of files

Arc currently supports Amazon S3 and local destinations for file uploads.

### Local Configuration
```elixir
defmodule Avatar do
  use Arc.Definition

  @versions [:original, :thumb]

  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100 -format png"}
  end

   def __storage, do: Arc.Storage.Local

   def filename(version,  file), do: "#{version}-#{file.file_name}"
end
```

### S3 Configuration

[Erlcloud](https://github.com/gleber/erlcloud) is used to support Amazon S3.

To store your attachments in Amazon S3, you'll need to provide your AWS credentials and bucket destination in your application config:

```elixir
config :arc,
  access_key_id: "AKIAGJAVFNWDALJDLSA",
  secret_access_key: "ncakAIWd+DaklwFAS51dDQo1i4EFAs\DASZGq",
  bucket: "uploads"
```

### Storage Directory

Arc requires the specification of a storage directory path (not including the bucket name).

The storage directory defaults to "uploads", but is recommended to configure based on your intended usage.  A common pattern for user profile pictures is to store each user's uploaded images in a separate subdirectory based on their primary key:

```elixir
def storage_dir(version, {file, scope}) do
  "uploads/users/avatars/#{scope.id}"
end
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

|ACL|Permissions Added to ACL|
|---|---|
|`:private`|Owner gets `FULL_CONTROL`. No one else has access rights (default).|
|`:public_read`|Owner gets `FULL_CONTROL`. The `AllUsers` group gets READ access.|
|`:public_read_write`|Owner gets `FULL_CONTROL`. The `AllUsers` group gets `READ` and `WRITE` access. Granting this on a bucket is generally not recommended.|
|`:authenticated_read`|Owner gets `FULL_CONTROL`. The `AuthenticatedUsers` group gets `READ` access.|
|`:bucket_owner_read`|Object owner gets `FULL_CONTROL`. Bucket owner gets `READ` access.|
|`:bucket_owner_full_control`|Both the object owner and the bucket owner get `FULL_CONTROL` over the object.|

For more information on the behavior of each of these, please consult Amazon's documentation for [Access Control List (ACL) Overview](https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html).

### File Validation

While storing files on S3 (rather than your harddrive) eliminates some malicious attack vectors, it is strongly encouraged to validate the extensions of uploaded files as well.

Arc delegates validation to a `validate/1` function with a tuple of the file and scope.  As an example, to validate that an uploaded file conforms to popular image formats, you may use:

```elixir
defmodule Avatar do
  use Arc.Definition

  def validate({file, _}) do
   ~w(.jpg .jpeg .gif .png) |> Enum.member?(Path.extname(file.file_name))
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
  "#{scope.id}_#{version}_#{file.file_name}"
end

# To make the destination file the same as the version:
def filename(version, _), do: version
```

## Url Generation

Saving your files is only the first half of any decent storage solution.  Straightforward access to your uploaded files is equally as important as storing them in the first place.

Often times you will want to regain access to the stored files.  As such, `Arc` facilitates the generation of urls.

```elixir
user = Repo.get(User, 1)

# To generate a regular, unsigned url (defaults to the first version):
Avatar.url({user.avatar, user}) #=> "https://bucket.s3.amazonaws.com/uploads/1/original.png"

# To specify the version of the upload:
Avatar.url({user.avatar, user}, :thumb) #=> "https://bucket.s3.amazonaws.com/uploads/1/thumb.png"

# To generate a signed url:
Avatar.url({user.avatar, user}, :thumb, signed: true) #=> "https://bucket.s3.amazonaws.com/uploads/1/thumb.png?AWSAccessKeyId=AKAAIPDF14AAX7XQ&Signature=5PzIbSgD1V2vPLj%2B4WLRSFQ5M%3D&Expires=1434395458"

# To generate urls for all versions:
Avatar.urls({user.avatar, user}) #=> %{original: "https://.../original.png", thumb: "https://.../thumb.png"}
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

**Asset Host**

You may optionally specify an asset host rather than using the default `bucket.s3.amazonaws.com` format.

In your application configuration, you'll need to provide an `asset_host` value:

```elixir
config :arc,
  asset_host: "https://d3gav2egqolk5.cloudfront.net"
```

# Full Example

```elixir
defmodule Avatar do
  use Arc.Definition

  @versions [:original, :thumb]
  @extension_whitelist ~w(.jpg .jpeg .gif .png)

  def acl(:thumb, _), do: :public_read

  def validate({file, _}) do
    @extension_whitelist |> Enum.member?(Path.extname(file.file_name))
  end

  def transform(:thumb, _) do
    {:convert, "-thumbnail 100x100^ -gravity center -extent 100x100 -format png"}
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

  * Object deletion
  * Cache-control headers
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
