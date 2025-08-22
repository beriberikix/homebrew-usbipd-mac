# typed: true
# frozen_string_literal: true

class UsbipdMac < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.24/usbipd-v0.1.24-macos"
  version "0.1.24"
  sha256 "460c5944ab7b398caffc86ad8f30d8ac7c215f29f3561a05bd6bbe3b41de59ed"

  depends_on :macos => :big_sur

  def install
    bin.install "usbipd-v0.1.24-macos" => "usbipd"
  end

  test do
    assert_match "USB/IP Daemon for macOS", shell_output("#{bin}/usbipd --version")
  end
end
