# encoding: UTF-8
#
# Cookbook Name:: ssl_certificate
# Library:: resource_ssl_certificate_chain
# Author:: Raul Rodriguez (<raul@onddo.com>)
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL. (www.onddo.com)
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

require 'chef/resource'
require 'openssl'

class Chef
  class Resource
    class SslCertificate < Chef::Resource
      # ssl_certificate Chef Resource cert related methods.
      module Chain
        # Resource certificate attributes to be initialized by a
        # `default#{attribute}` method.
        unless defined?(::Chef::Resource::SslCertificate::Chain::ATTRIBUTES)
          ATTRIBUTES = %w(
            chain_path
            chain_name
            chain_dir
            chain_source
            chain_bag
            chain_item
            chain_item_key
            chain_encrypted
            chain_secret_file
            chain_content
          )
        end

        unless defined?(::Chef::Resource::SslCertificate::Chain::SOURCES)
          SOURCES = %w(
            attribute
            data_bag
            chef_vault
            file
          )
        end

        public

        def initialize_chain_defaults
          ::Chef::Resource::SslCertificate::Chain::ATTRIBUTES.each do |var|
            instance_variable_set(
              "@#{var}".to_sym, send("default_#{var}")
            )
          end
        end

        def chain_name(arg = nil)
          set_or_return(:chain_name, arg, kind_of: String, required: false)
        end

        def chain_dir(arg = nil)
          set_or_return(:chain_dir, arg, kind_of: String)
        end

        def chain_path(arg = nil)
          set_or_return(:chain_path, arg, kind_of: String, required: false)
        end

        def chain_source(arg = nil)
          set_or_return(:chain_source, arg, kind_of: String)
        end

        def chain_bag(arg = nil)
          set_or_return(:chain_bag, arg, kind_of: String)
        end

        def chain_item(arg = nil)
          set_or_return(:chain_item, arg, kind_of: String)
        end

        def chain_item_key(arg = nil)
          set_or_return(:chain_item_key, arg, kind_of: String)
        end

        def chain_encrypted(arg = nil)
          set_or_return(:chain_encrypted, arg, kind_of: [TrueClass, FalseClass])
        end

        def chain_secret_file(arg = nil)
          set_or_return(:chain_secret_file, arg, kind_of: String)
        end

        def chain_content(arg = nil)
          set_or_return(:chain_content, arg, kind_of: String)
        end

        protected

        # chain private methods

        def default_chain_path
          lazy do
            unless chain_name.nil?
              @default_chain_path ||= ::File.join(chain_dir, chain_name)
            end
          end
        end

        def default_chain_name
          lazy { read_namespace(%w(ssl_chain name)) }
        end

        def default_chain_dir
          case node['platform']
          when 'debian', 'ubuntu'
            '/etc/ssl/certs'
          when 'redhat', 'centos', 'fedora', 'scientific', 'amazon'
            '/etc/pki/tls/certs'
          else
            '/etc'
          end
        end

        def default_chain_source
          lazy { read_namespace(%w(ssl_chain source)) }
        end

        def default_chain_bag
          lazy { read_namespace(%w(ssl_chain bag)) || read_namespace('bag') }
        end

        def default_chain_item
          lazy { read_namespace(%w(ssl_chain item)) || read_namespace('item') }
        end

        def default_chain_item_key
          lazy { read_namespace(%w(ssl_chain item_key)) }
        end

        def default_chain_encrypted
          lazy do
            read_namespace(%w(ssl_chain encrypted)) ||
              read_namespace('encrypted')
          end
        end

        def default_chain_secret_file
          lazy do
            read_namespace(%w(ssl_chain secret_file)) ||
              read_namespace('secret_file')
          end
        end

        def default_chain_content_from_attribute
          content = read_namespace(%w(ssl_chain content))
          unless content.is_a?(String)
            fail 'Cannot read SSL intermediary chain from content key value'
          end
          content
        end

        def default_chain_content_from_data_bag
          content = read_from_data_bag(
            chain_bag, chain_item, chain_item_key, chain_encrypted,
            chain_secret_file
          )
          unless content.is_a?(String)
            fail 'Cannot read SSL intermediary chain from data bag: '\
                 "#{chain_bag}.#{chain_item}->#{chain_item_key}"
          end
          content
        end

        def default_chain_content_from_chef_vault
          content = read_from_chef_vault(chain_bag, chain_item, chain_item_key)
          unless content.is_a?(String)
            fail 'Cannot read SSL intermediary chain from chef-vault: '\
                 "#{chain_bag}.#{chain_item}->#{chain_item_key}"
          end
          content
        end

        def default_chain_content_from_file
          content = read_from_path(chain_path)
          unless content.is_a?(String)
            fail "Cannot read SSL intermediary chain from path: #{chain_path}"
          end
          content
        end

        def default_chain_content
          lazy do
            @default_chain_content ||= begin
              source = chain_source.gsub('-', '_')
              unless Chain::SOURCES.include?(source)
                Chef::Log.debug('No SSL intermediary chain provided.')
                return nil
              end
              send("default_chain_content_from_#{source}")
            end # @default_chain_content ||=
          end # lazy
        end
      end
    end
  end
end
