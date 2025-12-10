echo "Starting with a blank template project."
npx degit evidence-dev/template . --force

echo "Files created are:"
ls -1

echo "Installing npm packages..."
npm install --silent --force

echo "Running the sources (alias evidence sources) cmd..."
npm run sources
