<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Coolify v5</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-900 text-white min-h-screen flex items-center justify-center">
    <div class="text-center">
        <h1 class="text-6xl font-bold mb-4 bg-gradient-to-r from-blue-400 to-purple-500 bg-clip-text text-transparent">
            Coolify v5
        </h1>
        <p class="text-xl text-gray-400 mb-8">Self-hosting made easy</p>
        <div class="space-y-4">
            <div class="flex items-center justify-center space-x-2">
                <span class="w-3 h-3 bg-green-500 rounded-full animate-pulse"></span>
                <span class="text-green-400">Application Running</span>
            </div>
            <p class="text-gray-500 text-sm">
                Laravel {{ app()->version() }} | PHP {{ PHP_VERSION }}
            </p>
        </div>
        <div class="mt-12 text-gray-600 text-sm">
            <p>This is a development preview of Coolify v5.</p>
            <p class="mt-2">The application is starting up correctly.</p>
        </div>
    </div>
</body>
</html>
