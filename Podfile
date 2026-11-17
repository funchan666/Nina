require_relative 'node_modules/react-native/scripts/react_native_pods'

nina_minimum_ios = '17.6'
platform :ios, nina_minimum_ios
prepare_react_native_project!
project 'Nina.xcodeproj'
workspace 'Nina.xcworkspace'

target 'Nina' do
  pod 'ZIPFoundation', '0.9.20'

  config = use_native_modules!

  use_react_native!(
    :path => config[:reactNativePath],
    :app_path => Pod::Config.instance.installation_root.to_s
  )

  post_install do |installer|
    react_native_post_install(installer, config[:reactNativePath], :mac_catalyst_enabled => false)

    # CocoaPods keeps ZIPFoundation's original minimum on its privacy resource bundle.
    privacy_bundle = installer.pods_project.targets.find do |target|
      target.name == 'ZIPFoundation-ZIPFoundation_Privacy'
    end
    privacy_bundle&.build_configurations&.each do |build_config|
      build_config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = nina_minimum_ios
    end
  end

  # Make the generated Pods target available when opening Nina.xcodeproj directly.
  post_integrate do |installer|
    pods_project = installer.pods_project
    app_project = Xcodeproj::Project.open(Pod::Config.instance.installation_root.join('Nina.xcodeproj'))
    app_target = app_project.native_targets.find { |target| target.name == 'Nina' }
    pods_target = pods_project.targets.find { |target| target.name == 'Pods-Nina' }
    reference = app_project.reference_for_path(pods_project.path) || app_project.new_file(pods_project.path)

    # Xcode expects a referenced project's Products group to contain only its product proxies.
    project_reference = app_project.root_object.project_references.find { |entry| entry[:project_ref] == reference }
    app_products = app_project.products_group
    if project_reference[:product_group] == app_products
      pods_products = app_project.new(Xcodeproj::Project::Object::PBXGroup)
      pods_products.name = 'Products'
      project_reference[:product_group] = pods_products

      app_products.children.grep(Xcodeproj::Project::Object::PBXReferenceProxy).each do |product|
        next unless product.remote_ref.container_portal == reference.uuid

        pods_products.children << product
        app_products.children.delete(product)
      end
    end

    app_target.dependencies.each do |dependency|
      proxy = dependency.target_proxy
      if proxy.container_portal == reference.uuid && proxy.remote_info == pods_target.name
        proxy.remote_global_id_string = pods_target.uuid
      end
    end
    app_target.add_dependency(pods_target)
    app_project.save
  end
end
