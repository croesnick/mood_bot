defmodule MoodBot.MixProject do
  use Mix.Project

  @app :mood_bot
  @version "0.1.0"
  @all_targets [
    :rpi0,
    :rpi3,
    :rpi3a,
    :rpi4,
    :rpi5,
    :x86_64
  ]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.18",
      archives: [nerves_bootstrap: "~> 1.13"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host],
      aliases: aliases(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {MoodBot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.10", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.4.0"},
      {:typedstruct, "~> 0.5.3"},

      # Image processing (host only - no cross-compilation issues)
      # {:image, "~> 0.61", targets: [:host]},
      {:image, "~> 0.62", targets: [:host]},
      # Nerves support was added just in time :)
      # We just need to use the master branch of vix and override the version restriction imposed by image.
      # See https://github.com/akash-akya/vix/issues/130
      {:vix,
       git: "https://github.com/akash-akya/vix.git",
       branch: "master",
       override: true,
       targets: [:host]},

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      {:nerves_runtime, "~> 0.13.0"},

      # Dependencies for all targets except :host
      {:nerves_pack, "~> 0.7.1", targets: @all_targets},
      {:circuits_gpio, "~> 2.0", targets: @all_targets},
      {:circuits_spi, "~> 2.0", targets: @all_targets},

      # Dependencies for specific targets
      # NOTE: It's generally low risk and recommended to follow minor version
      # bumps to Nerves systems. Since these include Linux kernel and Erlang
      # version updates, please review their release notes in case
      # changes to your application are needed.
      {:nerves_system_rpi0, "~> 1.24", runtime: false, targets: :rpi0},
      {:nerves_system_rpi3, "~> 1.31", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.24", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 1.24", runtime: false, targets: :rpi4},
      {:nerves_system_rpi5, "~> 0.2", runtime: false, targets: :rpi5},
      {:nerves_system_x86_64, "~> 1.24", runtime: false, targets: :x86_64},

      # Development and testing dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:dotenv, "~> 3.0", only: [:dev, :test], runtime: false}
    ]
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://hexdocs.pm/nerves_pack/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end

  defp aliases do
    [
      compile: ["compile", &copy_assets/1]
    ]
  end

  # Copy static assets from assets/ to priv/assets/ during compilation
  # This follows Nerves best practice: "add a line to your Makefile or mix.exs to copy them"
  # Reference: https://hexdocs.pm/nerves/compiling-non-beam-code.html#library-recommendations
  defp copy_assets(_args) do
    source_dir = "assets"
    target_dir = "priv/assets"

    if File.exists?(source_dir) do
      # Ensure target directory exists
      File.mkdir_p!(target_dir)

      # Copy all files from assets/ to priv/assets/
      case File.cp_r(source_dir, target_dir) do
        {:ok, _files} ->
          Mix.shell().info("Copied static assets from #{source_dir} to #{target_dir}")

        {:error, reason, file} ->
          Mix.shell().error("Failed to copy #{file}: #{reason}")
      end
    end
  end
end
