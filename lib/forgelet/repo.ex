defmodule Forgelet.Repo do
  use Ecto.Repo,
    otp_app: :forgelet,
    adapter: Ecto.Adapters.Postgres
end
