import React from 'react';
import './UserList.css';

function UserList({ users, onDelete }) {
  const formatDate = (dateString) => {
    const options = { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' };
    return new Date(dateString).toLocaleDateString('en-US', options);
  };

  return (
    <div className="user-list">
      {users.map(user => (
        <div key={user.id} className="user-card">
          <div className="user-header">
            <h3>{user.first_name} {user.last_name}</h3>
            <button 
              className="delete-btn" 
              onClick={() => onDelete(user.id)}
              title="Delete user"
            >
              ×
            </button>
          </div>
          
          <div className="user-info">
            <div className="info-item">
              <span className="label">Email:</span>
              <span className="value">{user.email}</span>
            </div>
            
            {user.phone && (
              <div className="info-item">
                <span className="label">Phone:</span>
                <span className="value">{user.phone}</span>
              </div>
            )}
            
            {user.message && (
              <div className="info-item">
                <span className="label">Message:</span>
                <span className="value message">{user.message}</span>
              </div>
            )}
            
            <div className="info-item timestamp">
              <span className="label">Added:</span>
              <span className="value">{formatDate(user.created_at)}</span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

export default UserList;
