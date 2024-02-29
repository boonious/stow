import Config

if Mix.env() == :test do
  config :stow,
    base_dir: ".",
    file_io: Stow.FileIOMock,
    http_client: Stow.Http.ClientMock
end
