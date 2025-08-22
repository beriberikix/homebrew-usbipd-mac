# typed: true
# frozen_string_literal: true

class UsbipdMac < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.20/usbipd-v0.1.20-macos"
  version "0.1.20"
  sha256 "c7640295c7e018e0c674a9c2db4bf36357d73015fa15355a68085a320cbaa223"

  depends_on :macos => :big_sur

  def install
    bin.install "usbipd-v0.1.20-macos" => "usbipd"
  end

  test do
    assert_match "USB/IP Daemon for macOS", shell_output("#{bin}/usbipd --version")
  end
end
