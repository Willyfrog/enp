// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.
import React from 'react';
import ReactDOM from 'react-dom';
import Container from 'react-bootstrap/Container';
import Row from 'react-bootstrap/Row';
import Col from 'react-bootstrap/Col';


import MainNotifier from './mainNotifier.jsx';
import RendererNotifier from './rendererNotifier.jsx';

const content = document.getElementById('app');

ReactDOM.render(
  <Container fluid >
    <Row>
      <Col>
        <MainNotifier/>
      </Col>
      <Col>
        <RendererNotifier/>
      </Col>
    </Row>
  </Container>,
  content,
);