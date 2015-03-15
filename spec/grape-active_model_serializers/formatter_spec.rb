require 'spec_helper'
require 'grape-active_model_serializers/formatter'

describe Grape::Formatter::ActiveModelSerializers do
  subject { Grape::Formatter::ActiveModelSerializers }

  describe 'serializer options from namespace' do
    let(:app) { Class.new(Grape::API) }

    before do
      app.format :json
      app.formatter :json, Grape::Formatter::ActiveModelSerializers

      app.namespace('space') do |ns|
        ns.get('/', root: false) do
          { user: { first_name: 'JR', last_name: 'HE' } }
        end
      end
    end

    it 'should read serializer options like "root"' do
      expect(described_class.build_options_from_endpoint(User.new, app.endpoints.first)).to include :root
    end
  end

  describe '.fetch_serializer' do
    let(:user) { User.new(first_name: 'John') }

    if Grape::Util.const_defined?('InheritableSetting')
      let(:endpoint) { Grape::Endpoint.new(Grape::Util::InheritableSetting.new, path: '/', method: 'foo', root: false) }
    else
      let(:endpoint) { Grape::Endpoint.new({}, path: '/', method: 'foo', root: false) }
    end

    let(:env) { { 'api.endpoint' => endpoint } }

    before do
      def endpoint.current_user
        @current_user ||= User.new(first_name: 'Current user')
      end

      def endpoint.default_serializer_options(resource)
        if current_user.first_name == resource.first_name
          { only: [:secret_token], except: :except }
        else
          { only: [:public_token], except: :except }
        end
      end
    end

    subject { described_class.fetch_serializer(user, env) }

    it { should be_a UserSerializer }

    it 'should have correct scope set' do
      expect(subject.scope.current_user).to eq(endpoint.current_user)
    end

    it 'should read default serializer options' do
      expect(subject.instance_variable_get('@only')).to eq([:public_token])
      expect(subject.instance_variable_get('@except')).to eq([:except])
    end

    it 'should read serializer options like "root"' do
      expect(described_class.build_options_from_endpoint(user, endpoint).keys).to include :root
    end

    it 'can take resource as parameter' do
      expect {
        user.first_name = 'Current user'
      }.to change { described_class.fetch_serializer(user, env).instance_variable_get('@only') }.from([:public_token]).to([:secret_token])
    end
  end
end
