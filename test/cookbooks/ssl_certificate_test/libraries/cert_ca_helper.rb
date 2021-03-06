# encoding: UTF-8
#
# Cookbook Name:: ssl_certificate_test
# Library:: cert_ca_helper
# Description:: Library to create Certificate Authority.
# Author:: Jeremy MAURO (<j.mauro@criteo.com>)
# Author:: Xabier de Zuazo (<xabier@zuazo.org>)
# Copyright:: Copyright (c) 2016 Xabier de Zuazo
# Copyright:: Copyright (c) 2014 Onddo Labs, SL.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Helper module to create Certificate Authority certificates.
module CACertificate
  require 'openssl'
  extend ::Chef::Resource::SslCertificate::Generators

  unless defined?(CACertificate::EXTENSIONS)
    EXTENSIONS = [
      %w(subjectKeyIdentifier hash),
      ['basicConstraints', 'CA:TRUE', true],
      ['keyUsage', 'cRLSign,keyCertSign', true]
    ].freeze
  end

  def self.key_to_file(key_file, pass_phrase = nil)
    key = OpenSSL::PKey::RSA.new(2048)
    open(key_file, 'w', 0400) do |io|
      if pass_phrase
        cipher = OpenSSL::Cipher::Cipher.new('AES-128-CBC')
        io.write key.export(cipher, pass_phrase)
      else
        io.write key.to_pem
      end
    end
  end

  def self.generate_ca_cert_extensions(cert)
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert_add_extensions(cert, ef, CACertificate::EXTENSIONS)
    ef
  end

  def self.generate_self_signed_ca_cert(key, cert, subject)
    cert.public_key = key.public_key
    cert.subject = generate_cert_subject(subject)
    cert.issuer = cert.subject
    _ef = generate_ca_cert_extensions(cert)
    cert
  end

  def self.ca_cert_to_file(subject, key_file, cert_file, time, key_pass = nil)
    key = File.open(key_file, 'rb', &:read)

    key, cert = generate_generic_x509_key_cert(key, time, key_pass)

    generate_self_signed_ca_cert(key, cert, subject)

    cert.sign(key, OpenSSL::Digest::SHA1.new)
    open(cert_file, 'w') { |io| io.write cert.to_pem }
  end
end
