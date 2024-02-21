import Config

if Mix.env() == :test do
  config :stow,
    file_io: Stow.FileIOMock,
    http_client: Stow.Http.ClientMock
end
