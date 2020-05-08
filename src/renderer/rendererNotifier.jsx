import React, {Fragment} from 'react';
import Button from 'react-bootstrap/Button';

import 'bootstrap/dist/css/bootstrap.min.css';

export default class RendererNotifier extends React.PureComponent {
  constructor() {
    super();
    this.state = {
      shown: 0,
      clicked: 0,
      ignored: 0,
    }
  }

  buttonClick = (e) => {
    console.log('creating HTML5 notification');
    if (Notification.permission === 'default') {
      Notification.requestPermission();
    }
    const htmlNotification = new Notification(`HTML5 Notification x ${this.state.shown + 1}`);
    htmlNotification.onshow = this.notificationShow;
    htmlNotification.onclick = this.notificationClick;
    htmlNotification.onclose = this.notificationIgnored;
  }

  notificationClick = (e) => {
    console.log('html notification clicked');
    this.setState({clicked: this.state.clicked + 1});
  }

  notificationShow = (e) => {
    console.log('html notification showed');
    this.setState({shown: this.state.shown + 1});
  }

  notificationIgnored = (e) => {
    console.log(`html notification ignored`);
    this.setState({ignored: this.state.ignored + 1});
  }

  render() {
    return (<div>
      <Button onClick={this.buttonClick}>{'Renderer Notification'}</Button>
      <ul>
        <li>{`notifications: ${this.state.shown}`}</li>
        <li>{`clicked: ${this.state.clicked}`}</li>
        <li>{`closed: ${this.state.ignored}`}</li>

      </ul>
    </div>);
  }
}