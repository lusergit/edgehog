defmodule Edgehog.Users do
  @moduledoc false
  use Ash.Domain,
    otp_app: :edgehog

  resources do
    resource Edgehog.Users.User
  end
end
