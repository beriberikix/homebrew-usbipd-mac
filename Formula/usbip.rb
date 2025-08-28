# typed: true
# frozen_string_literal: true

class Usbip < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.33/usbipd-v0.1.33-macos"
  sha256 "b7fdcfa514cb126ef78178c03b7b37506cb98f3349461e38709f62d4a4c5f097"

  depends_on macos: :big_sur

  # System extension resource
  resource "systemextension" do
    url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.33/USBIPDSystemExtension.systemextension.tar.gz"
    sha256 "4e712eb342d5f52dde115812c2596a8715c33552558238e719d05ade8288d0e3"
  end

  def install
    bin.install "usbipd-v0.1.33-macos" => "usbipd"

    # Generate and install shell completion scripts
    # Note: This temporary approach will be replaced by including pre-generated
    # completion scripts in the release artifacts in future versions
    mkdir_p "completions"

    # Generate completion scripts using the installed binary
    system bin/"usbipd", "completion", "generate", "--output", "completions"

    # Install shell completions to appropriate directories
    bash_completion.install "completions/usbipd" if File.exist?("completions/usbipd")
    zsh_completion.install "completions/_usbipd" if File.exist?("completions/_usbipd")
    fish_completion.install "completions/usbipd.fish" if File.exist?("completions/usbipd.fish")

    # Install system extension bundle
    resource("systemextension").stage do
      # Create system extension directory in expected Library/SystemExtensions path
      (prefix/"Library/SystemExtensions").mkpath

      # The tar.gz extracts to just "Contents" directory, so we need to reconstruct the bundle
      if Dir.exist?("Contents")
        puts "Found Contents directory, reconstructing system extension bundle..."
        bundle_dir = prefix/"Library/SystemExtensions"/"USBIPDSystemExtension.systemextension"
        bundle_dir.mkpath
        cp_r "Contents", bundle_dir
        puts "System extension bundle created at: #{bundle_dir}"
      elsif Dir.glob("*.systemextension").any?
        # If we have a .systemextension directory, copy it directly
        Dir.glob("*.systemextension") do |bundle|
          puts "Found system extension bundle: #{bundle}"
          cp_r bundle, prefix/"Library/SystemExtensions"
        end
      else
        puts "Warning: No system extension bundle found in staged directory"
        puts "Contents: #{Dir.glob("*").inspect}"
      end
    end
  end

  def post_install
    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "  🔧 Additional Setup Required"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
    puts "To complete installation and enable system extension functionality:"
    puts
    puts "  1. Install the system extension:"
    puts "     sudo usbipd install-system-extension"
    puts
    puts "  2. Start the service:"
    puts "     sudo brew services start usbip"
    puts
    puts "  3. Approve the system extension in:"
    puts "     System Preferences → Security & Privacy → General"

    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "  🐚 Shell Completions Installed"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
    puts "Shell completions have been automatically installed and should be available"
    puts "in new shell sessions for enhanced CLI experience with tab completion."
    puts
    puts "Supported shells: bash, zsh, fish"
    puts "Type 'usbipd ' and press <TAB> to test completion functionality."
    puts
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts
  end

  service do
    run [opt_bin/"usbipd", "daemon"]
    keep_alive true
    require_root true
    log_path "/var/log/usbipd.log"
    error_log_path "/var/log/usbipd.error.log"
  end

  test do
    assert_match "USB/IP Daemon for macOS", shell_output("#{bin}/usbipd --version")
    assert_path_exists "#{prefix}/Library/SystemExtensions/USBIPDSystemExtension.systemextension"

    # Test that shell completion files are installed
    assert_path_exists "#{bash_completion}/usbipd"
    assert_path_exists "#{zsh_completion}/_usbipd"
    assert_path_exists "#{fish_completion}/usbipd.fish"

    # Test that completion command works
    assert_match "Completion Generation Summary", shell_output("#{bin}/usbipd completion generate --output /tmp/test-completions 2>&1")
  end
end