module.exports = {
  module: {
    rules: [
      // {
      //   test: /\.(js|jsx)$/,
      //   loader: "babel-loader",
      //   options: {
      //     include: ["@babel/plugin-proposal-class-properties"]
      //   }
      // }
      {
        test: /\.jsx?$/,
        exclude: /node_modules/,
        use: [
          {
            loader: 'babel-loader',
            options: {
              presets: ['@babel/react'],
              plugins: ['@babel/plugin-proposal-class-properties']
            }
          }
      ]
      }
    ]
  },
  resolve: {
      extensions: ['.js', '.jsx']
    }
};