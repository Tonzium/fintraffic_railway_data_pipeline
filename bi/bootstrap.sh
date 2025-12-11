if [ ! -d 'node_modules/@evidence-dev' ]; then
    echo "node_modules does not exist, installing dependencies..."
    npm install --silent
else
    echo "node_modules exists, skipping installation..."
fi


# Running the sources script to update the Evidence sources
npm run sources

# Run the dev server
npm run dev -- --host 0.0.0.0
