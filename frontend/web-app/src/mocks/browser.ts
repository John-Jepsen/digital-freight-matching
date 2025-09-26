import axios from 'axios';
import AxiosMockAdapter from 'axios-mock-adapter';

export function enableAxiosMocks() {
  const mock = new AxiosMockAdapter(axios, { delayResponse: 300 });

  // Health
  mock.onGet(/\/api\/v1\/health$/).reply(200, {
    status: 'ok',
    service: 'Digital Freight Matching API (mock)',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    environment: 'mock',
    database: 'connected',
    redis: 'connected'
  });

  // Loads (list)
  mock.onGet(/\/api\/v1\/loads$/).reply(200, [
    { id: 1, origin: 'DAL, TX', destination: 'ATL, GA', status: 'posted', equipment_type: 'van', total_rate: 1800 },
    { id: 2, origin: 'LAX, CA', destination: 'SEA, WA', status: 'booked', equipment_type: 'reefer', total_rate: 2400 },
    { id: 3, origin: 'ORD, IL', destination: 'MSP, MN', status: 'posted', equipment_type: 'flatbed', total_rate: 1600 }
  ]);

  // Carriers (list)
  mock.onGet(/\/api\/v1\/carriers$/).reply(200, [
    { id: 'C1001', name: 'Acme Logistics', is_active: true, trucks: 12 },
    { id: 'C1002', name: 'NorthStar Freight', is_active: true, trucks: 7 },
    { id: 'C1003', name: 'Rivertown Carriers', is_active: false, trucks: 4 }
  ]);

  // Fallback passthrough to real API:
  mock.onAny().passThrough();
}
