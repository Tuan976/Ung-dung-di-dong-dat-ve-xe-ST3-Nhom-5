export const getPermissions = (role, staffRole) => {
  const r = role?.toUpperCase();
  const sr = staffRole?.toUpperCase();
  
  if (r === 'ADMIN' || r === 'COMPANY') return ['ALL'];
  if (r === 'STAFF') {
    if (sr === 'STATION_STAFF') return ['DASHBOARD', 'TRIPS', 'WAREHOUSE', 'CARGO'];
    if (sr === 'TICKET_OFFICE') return ['DASHBOARD', 'TRIPS', 'CARGO'];
    if (sr === 'DRIVER' || sr === 'ASSISTANT') return ['TRIPS'];
  }
  return [];
};
