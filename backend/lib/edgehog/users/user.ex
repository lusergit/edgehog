defmodule Edgehog.Users.User do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Users

  attributes do
    uuid_primary_key :id

    attribute :username, :string do
      allow_nil? false
    end

    timestamps()
  end
end
