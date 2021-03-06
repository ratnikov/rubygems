require 'rubygems/test_case'
require 'rubygems/source'

class TestGemSourceGit < Gem::TestCase

  def setup
    super

    @name, @version, @repository, @head = git_gem

    @hash = Digest::SHA1.hexdigest @repository

    @source = Gem::Source::Git.new @name, @repository, 'master', false
  end

  def test_checkout
    @source.checkout

    assert_path_exists File.join @source.install_dir, 'a.gemspec'
  end

  def test_checkout_submodules
    source = Gem::Source::Git.new @name, @repository, 'master', true

    git_gem 'b'

    Dir.chdir 'git/a' do
      system @git, 'submodule', '--quiet', 'add', File.expand_path('../b'), 'b'
      system @git, 'commit', '--quiet', '-m', 'add submodule b'
    end

    source.checkout

    assert_path_exists File.join source.install_dir, 'a.gemspec'
    assert_path_exists File.join source.install_dir, 'b/b.gemspec'
  end

  def test_cache
    assert @source.cache

    assert_path_exists @source.repo_cache_dir

    Dir.chdir @source.repo_cache_dir do
      assert_equal @head, Gem::Util.popen(@git, 'rev-parse', 'master').strip
    end
  end

  def test_dir_shortref
    @source.cache

    assert_equal @head[0..11], @source.dir_shortref
  end

  def test_equals2
    assert_equal @source, @source

    assert_equal @source, @source.dup

    source =
      Gem::Source::Git.new @source.name, @source.repository, 'other', false

    refute_equal @source, source

    source =
      Gem::Source::Git.new @source.name, 'repo/other', @source.reference, false

    refute_equal @source, source

    source =
      Gem::Source::Git.new 'b', @source.repository, @source.reference, false

    refute_equal @source, source

    source =
      Gem::Source::Git.new @source.name, @source.repository, @source.reference,
                           true

    refute_equal @source, source
  end

  def test_install_dir
    @source.cache

    expected = File.join Gem.dir, 'bundler', 'gems', "a-#{@head[0..11]}"

    assert_equal expected, @source.install_dir
  end

  def test_repo_cache_dir
    expected =
      File.join Gem.dir, 'cache', 'bundler', 'git', "a-#{@hash}"

    assert_equal expected, @source.repo_cache_dir
  end

  def test_rev_parse
    @source.cache

    assert_equal @head, @source.rev_parse

    Dir.chdir @repository do
      system @git, 'checkout', '--quiet', '-b', 'other'
    end

    master_head = @head

    git_gem 'a', 2

    source = Gem::Source::Git.new @name, @repository, 'other', false

    source.cache

    refute_equal master_head, source.rev_parse
  end

  def test_spaceship
    git       = Gem::Source::Git.new 'a', 'git/a', 'master', false
    remote    = Gem::Source.new @gem_repo
    installed = Gem::Source::Installed.new

    assert_equal( 0, git.      <=>(git),       'git    <=> git')

    assert_equal( 1, git.      <=>(remote),    'git    <=> remote')
    assert_equal(-1, remote.   <=>(git),       'remote <=> git')

    assert_equal( 1, installed.<=>(git),       'installed <=> git')
    assert_equal(-1, git.      <=>(installed), 'git       <=> installed')
  end

  def test_specs
    source = Gem::Source::Git.new @name, @repository, 'master', true

    Dir.chdir 'git/a' do
      FileUtils.mkdir 'b'

      Dir.chdir 'b' do
        b = Gem::Specification.new 'b', 1

        open 'b.gemspec', 'w' do |io|
          io.write b.to_ruby
        end

        system @git, 'add', 'b.gemspec'
        system @git, 'commit', '--quiet', '-m', 'add b/b.gemspec'
      end

      FileUtils.touch 'c.gemspec'

      system @git, 'add', 'c.gemspec'
      system @git, 'commit', '--quiet', '-m', 'add c.gemspec'
    end

    specs = nil

    capture_io do
      specs = source.specs
    end

    assert_equal %w[a-1 b-1], specs.map { |spec| spec.full_name }
  end

  def test_uri_hash
    assert_equal @hash, @source.uri_hash

    source =
      Gem::Source::Git.new 'a', 'http://git@example/repo.git', 'master', false

    assert_equal '291c4caac7feba8bb64c297987028acb3dde6cfe',
                 source.uri_hash

    source =
      Gem::Source::Git.new 'a', 'HTTP://git@EXAMPLE/repo.git', 'master', false

    assert_equal '291c4caac7feba8bb64c297987028acb3dde6cfe',
                 source.uri_hash
  end

end

