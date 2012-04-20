require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'rubygems'
require 'acdata-dataset-api'
require 'webmock/rspec'
require 'tempfile'

describe ACDataDatasetAPI do

  let(:session_cookie_value){'I_am_a_session_cookie_value'}
  let(:signin_json){
    '{ "user": { "first_name":"Ada", "last_name":"Lovelace", "login":"z1234567", "phone_number":null } }'
  }
  let(:instruments_json){
'{"instruments":{"FTIR":[{"name":"Perkin Elmer Spotlight 400 FTIR Microscope","id":2}],"NMR":[{"name":"Bruker Avance III 300 Solid State (Pines)","id":3}],"Porometer":[{"name":"PMI Capillary Flow Porometer","id":9}],"Potentiostats":[{"name":"Autolab PGSTAT 12 Potentiostat","id":10}],"Raman Spectrometers":[{"name":"Perkin Elmer Ramanstation 400","id":12}]}}'
  }
  let(:samples_json){
'{"samples":[{"id":16,"name":"Raman instrument sample (sp metadata file)","datasets":["Et Laudantium"]},{"id":17,"name":"NMR instrument sample","datasets":["Et Quod"]},{"id":18,"name":"FTIR instrument sample (JCAMP-DX metadata file)","datasets":["Repellat Dolores"]},{"id":26,"name":"Raman instrument sample (sp metadata file)","datasets":["Nam Consequatur"]}],"projects":{"owner":[{"name":"Odit Laborum Optio","experiments":[],"samples":[{"id":16,"name":"Raman instrument sample (sp metadata file)","datasets":["Et Laudantium"]},{"id":17,"name":"NMR instrument sample","datasets":["Et Quod"]},{"id":18,"name":"FTIR instrument sample (JCAMP-DX metadata file)","datasets":["Repellat Dolores"]}]},{"name":"Illum Consequuntur Ad","experiments":[],"samples":[]},{"name":"Officiis Praesentium Commodi Assumenda Quae","experiments":[],"samples":[]}],"collaborator":[{"name":"Non Voluptatem Omnis","experiments":[],"samples":[{"id":26,"name":"Raman instrument sample (sp metadata file)","datasets":["Nam Consequatur"]}]}]}}'
  }
  let(:projects_json){
'{"projects":[{"id":82, "name":"Facilis Aut Voluptatem"}, {"id":83, "name":"Et Tenetur"}, {"id":84, "name":"Quisquam Velit"}, {"id":146, "name":"NMR Server Data"}]}'
  }
  let(:create_sample_json){ '{"id":1}' }

  before :each do
    post_body = '{"user":{"login":"z1234567","password":"Pass.123"}}'
    stub_request(:post, 'http://example.com/users/sign_in.json').with(:body => post_body).to_return(:body => signin_json, :headers => { 'Set-Cookie' => "_acdata_session=#{session_cookie_value}"}, :status => [201, 'Created'])
    @api = ACDataDatasetAPI.new('http://example.com')
    @session_id = @api.login('z1234567', 'Pass.123')
  end

  it "should login" do
    @session_id.should == session_cookie_value
  end

  it "should list instruments" do
    stub_request(:get, 'http://example.com/api/instruments').to_return(:body => instruments_json, :status => [200, 'OK'])
    instruments = @api.instruments(@session_id)
    instruments.should have_key('instruments')
  end

  it "should list samples" do
    stub_request(:get, 'http://example.com/api/samples').to_return(:body => samples_json, :status => [200, 'OK'])
    samples = @api.samples(@session_id)
    samples.should have_key('samples')
  end

  it "should list projects" do
    stub_request(:get, 'http://example.com/api/projects').to_return(:body => projects_json, :status => [200, 'OK'])
    projects = @api.projects(@session_id)
    projects.should have_key('projects')
  end

  describe "creating samples" do
    it "should create a sample under a project" do
      create_sample(1)
    end

    it "should create a sample under an experiment" do
      create_sample(1, 1)
    end

    def create_sample(p_id, e_id=nil)
      post_body = {"project_id" => p_id,"experiment_id" => e_id,"sample" => {"name" => "Test from API","description" => nil}}.to_json
      stub_request(:post, 'http://example.com/api/samples').with(:body => post_body).to_return(:body => create_sample_json, :status => [201, 'Created'])
      @api.create_sample(
        @session_id, :project_id => p_id, :experiment_id => e_id, :name => 'Test from API')
    end
  end

  it "should create datasets" do
    resources_path = File.expand_path('../resources', __FILE__)
    post_body_path = File.join(resources_path, 'dataset_create_post_body')
    post_body = File.read(post_body_path)
    resp_body = {
      "test2.txt" => {"status" => "success","message" => ""},
      "test.txt" => {"status" => "success","message" => ""}
    }
    stub_request(:post, 'http://example.com/api/datasets')
      .with(:body => post_body)
      .to_return(:body => resp_body.to_json, :status => 201)
    files = Dir.glob(File.join(resources_path, '*.txt'))
    name = 'API dataset creation test 1'
    metadata = {
      'key1' => 'value1',
      'key2' => 'value2'
    }
    instrument_id =
      JSON.parse(instruments_json)['instruments']['FTIR'].first['id']
    sample_id = JSON.parse(samples_json)['samples'].first['id']
    @api = ACDataDatasetAPI.new('http://example.com')
    dataset = @api.create_dataset(session_cookie_value, name, instrument_id, sample_id, files, metadata)
    dataset.should == resp_body
  end

  it "should produce a mapping of files needed for file uploads" do
    file1 = Tempfile.new('file')
    file2 = Tempfile.new('file')
    begin
      files_list, file_map =
        ACDataDatasetAPI.build_files_structure([file1, file2])
      expected = [
        {"file_1"=>File.basename(file1)},
        {"file_2"=>File.basename(file2)}
      ]
      files_list.should =~ expected
      file_map.keys.should =~ %w{file_1 file_2}
      files_list.each do |entry|
        k = entry.keys.first
        File.basename(file_map[k].path).should == entry[k]
      end
    ensure
      file1.close
      file2.close
      file1.unlink
      file2.unlink
    end
  end

end
