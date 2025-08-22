# typed: true
# frozen_string_literal: true

class UsbipdMac < Formula
  desc "Macos implementation of the usb/ip protocol"
  homepage "https://github.com/beriberikix/usbipd-mac"
  url "https://github.com/beriberikix/usbipd-mac/releases/download/v0.1.26/usbipd-v0.1.26-macos"
  version "0.1.26"
  sha256 "d4ca2711899d15824b4f6a3b5d31e0e6ce039fe34676548617f11ed4b60d9466"

  depends_on :macos => :big_sur

  def install
    bin.install "usbipd-v0.1.26-macos" => "usbipd"
  end

  test do
    assert_match "USB/IP Daemon for macOS", shell_output("#{bin}/usbipd --version")
  end
end
