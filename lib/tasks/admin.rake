namespace :admin do
    desc "Crear el primer administrador"
    task create: :environment do
      require "io/console"
  
      print "Email del administrador: "
      email = STDIN.gets.chomp
  
      print "Contraseña: "
      password = STDIN.noecho(&:gets).chomp
      puts
  
      print "Confirmar contraseña: "
      confirmation = STDIN.noecho(&:gets).chomp
      puts
  
      abort "Las contraseñas no coinciden." unless password == confirmation
  
      user = User.create!(
        email_address: email,
        password: password,
        password_confirmation: confirmation,
        role: "admin"
      )
  
      puts "Administrador creado: #{user.email_address}"
    end
  end