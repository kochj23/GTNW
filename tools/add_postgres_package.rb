#!/usr/bin/env ruby
# Adds PostgresNIO (re-exports NIOSSL, used for the pinned-CA TLS config) to the macOS and iOS app targets.
# Idempotent. Run from the repo root: ruby tools/add_postgres_package.rb
require 'xcodeproj'

project = Xcodeproj::Project.open('GTNW.xcodeproj')

PACKAGES = [
  { url: 'https://github.com/vapor/postgres-nio.git', min: '1.33.1', products: ['PostgresNIO'] },
]
TARGETS = %w[GTNW_macOS GTNW_iOS]

PACKAGES.each do |pkg|
  ref = project.root_object.package_references.find { |r| r.respond_to?(:repositoryURL) && r.repositoryURL == pkg[:url] }
  unless ref
    ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    ref.repositoryURL = pkg[:url]
    ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => pkg[:min] }
    project.root_object.package_references << ref
  end
  TARGETS.each do |tname|
    target = project.targets.find { |t| t.name == tname } or abort "missing target #{tname}"
    pkg[:products].each do |product|
      next if target.package_product_dependencies.any? { |d| d.product_name == product }
      dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
      dep.package = ref
      dep.product_name = product
      target.package_product_dependencies << dep
      bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
      bf.product_ref = dep
      target.frameworks_build_phase.files << bf
    end
  end
end

project.save
puts 'PostgresNIO linked into ' + TARGETS.join(', ')
