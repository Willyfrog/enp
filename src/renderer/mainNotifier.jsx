import React, {Fragment} from 'react';
import Button from 'react-bootstrap/Button';

import 'bootstrap/dist/css/bootstrap.min.css';
import { ipcRenderer } from 'electron';

export default class MainNotifier extends React.PureComponent {
  constructor() {
    super();
    this.state = {
      shown: 0,
      clicked: 0,
      ignored: 0,
    }
  }

  sendNotification = () => {
    const result = ipcRenderer.invoke('notify', {message: `Main notification x ${this.state.shown}`});
    this.setState({shown: this.state.shown + 1});

    result.then(({action}) => {
      if (action === 'clicked') {
        this.setState({clicked: this.state.clicked + 1});
      } else if (action === 'closed') {
        this.setState({ignored: this.state.ignored + 1});
      }
    });
  }

  render() {
    return (
      <div>
        <Button onClick={this.sendNotification}>{'Main Notification'}</Button>
        <ul>
          <li>{`notifications: ${this.state.shown}`}</li>
          <li>{`clicked: ${this.state.clicked}`}</li>
          <li>{`ignored: ${this.state.ignored}`}</li>

        </ul>
      </div>
    );
  }
}