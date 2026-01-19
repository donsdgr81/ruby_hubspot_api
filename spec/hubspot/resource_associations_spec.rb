# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hubspot::Resource do
  describe 'Associations support' do
    let(:api_root) { 'https://api.hubapi.com/crm/v3/objects/resources' }
    
    describe '.create', configure_hubspot: true do
      let(:params) { { name: 'Test Resource' } }
      
      context 'with associations' do
        let(:associations) do
          [
            { to_id: 123, association_type_id: 1 },
            { to_id: 456, association_type_id: 2, association_category: 'USER_DEFINED' }
          ]
        end
        
        before do
          stub_request(:post, api_root).to_return(status: 201, body: { id: 1, properties: params }.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'sends associations in the payload' do
          described_class.create(params.merge(associations: associations))
          
          expect(WebMock).to have_requested(:post, api_root).with { |req|
            body = JSON.parse(req.body)
            expect(body['properties']).to eq('name' => 'Test Resource')
            expect(body['associations']).to be_an(Array)
            expect(body['associations'].length).to eq(2)
            expect(body['associations'][0]['to']['id']).to eq(123)
            expect(body['associations'][0]['types'][0]['associationTypeId']).to eq(1)
            expect(body['associations'][0]['types'][0]['associationCategory']).to eq('HUBSPOT_DEFINED')
            expect(body['associations'][1]['to']['id']).to eq(456)
            expect(body['associations'][1]['types'][0]['associationCategory']).to eq('USER_DEFINED')
          }
        end
      end
    end

    describe '.update', configure_hubspot: true do
      let(:id) { 1 }
      let(:params) { { name: 'Updated Name' } }
      let(:associations) { [{ to_id: 123, to_object_type: 'companies', association_type_id: 1 }] }
      
      before do
        stub_request(:patch, "#{api_root}/#{id}").to_return(status: 200, body: { id: id, properties: params }.to_json, headers: { 'Content-Type' => 'application/json' })
        allow(described_class).to receive(:associate)
      end

      it 'calls associate for each association after update' do
        described_class.update(id, params, associations: associations)
        
        expect(WebMock).to have_requested(:patch, "#{api_root}/#{id}")
        expect(described_class).to have_received(:associate).with(
          id,
          123,
          to_object_type: 'companies',
          association_type_id: 1,
          association_category: 'HUBSPOT_DEFINED'
        )
      end
    end
    
    describe 'Instance methods', configure_hubspot: true do
      let(:resource) { described_class.new(name: 'Test') }
      
      describe '#associations=' do
        it 'sets pending associations' do
          assocs = [{ to_id: 1, association_type_id: 2 }]
          resource.associations = assocs
          expect(resource.pending_associations).to eq(assocs)
        end
      end
      
      describe '#save' do
        context 'when creating new' do
          before do
            allow(described_class).to receive(:create).and_return(double(id: 1, properties: {}, changes: {}))
          end
          
          it 'passes associations to create' do
            resource.associations = [{ to_id: 1, association_type_id: 2 }]
            resource.save
            
            expect(described_class).to have_received(:create).with(hash_including(associations: [{ to_id: 1, association_type_id: 2 }]))
          end
        end
        
        context 'when updating existing' do
          let(:resource) { described_class.new(id: 1, properties: { name: 'Old' }) }
          
          before do
            stub_request(:patch, "#{api_root}/1").to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })
            allow(described_class).to receive(:update).and_call_original
            allow(described_class).to receive(:associate)
          end
          
          it 'passes associations to update' do
            resource.name = 'New'
            resource.associations = [{ to_id: 2, to_object_type: 'companies', association_type_id: 3 }]
            resource.save
            
            expect(described_class).to have_received(:update).with(
              1, 
              hash_including('name' => 'New'), 
              associations: [{ to_id: 2, to_object_type: 'companies', association_type_id: 3 }]
            )
          end
        end
      end
    end
  end
end
