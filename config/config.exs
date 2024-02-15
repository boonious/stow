import Config

if Mix.env() == :test do
  config :stow, :file_io, Stow.FileIO.Mock
end
