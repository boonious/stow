import Config

if Mix.env() == :test do
  config :stow,
    base_dir: ".",
    file_io: Stow.FileIOMock,
    adapter: %{"http" => Stow.Adapter.HttpMock}
end
