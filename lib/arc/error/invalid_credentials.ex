defmodule Arc.Error.InvalidCredentialsError do
    defexception message: "Please set both access_key_id and secret_access_key in the config"
end
